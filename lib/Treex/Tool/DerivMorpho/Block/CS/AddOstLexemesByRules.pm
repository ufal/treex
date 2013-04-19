package Treex::Tool::DerivMorpho::Block::CS::AddOstLexemesByRules;
use Moose;
extends 'Treex::Tool::DerivMorpho::Block';

use Treex::Tool::Lexicon::CS;
use CzechMorpho;

sub acceptable_adj { # adjectives that are not recognized by JH's morphology but are more or less acceptable
    my $adj = shift;
    return $adj =~ /^(bezdějinný|bezprincipiální|dosebezahleděný|držebný|dvojpolární|dvojtvářný|glasný|házivý|jaký|kazivý|kovnatý|mačkavý|metaznalý|mikrotvrdý|mrtvorozený|nasáklivý|neprůzvučný|neslučivý|obložný|osobivý|podposloupný|podujatý|podzaměstnaný|prazkušený|propojištěný|pseudoskutečný|pseudoudálý|pufrovitý|pórézní|předvádivý|přináležitý|příležitý|působný|různočnělečný|sebedůležitý|sebelítý|sebezahleděný|slučivý|soběpodobný|soudružný|soumezný|spolupůsobný|střečkovitý|subkontrární|supermocný|supermožný|svalovčitý|ujímavý|videospolečný|vzcházivý|váživý|špinivý|žánrovitý)$/
}

sub process_dictionary {
    my ($self,$dict) = @_;

    my $analyzer = CzechMorpho::Analyzer->new();


    my %non_deadj;
    open my $N, '<:utf8', $self->my_directory.'/manual.AddOstLexemesByRules.nondeadjective.tsv' or die $!;
    while (<$N>) {
        chomp;
        my ($noun,$source) = split /\t/;
        $non_deadj{$noun} = 1;
    }

    open my $R, '<:utf8',  $self->my_directory.'/manual.AddOstLexemesByRules.suffix.tsv' or die $!;
    my @rules;
    while (<$R>) {
        next if $.==0;
        chomp;

        s/, +/,/g;
        s/\s/\|/g;
        my ($old_suffix, $new_suffix, $type, $dummy, $exceptions, $exception_type) = split /\|/;

        next if not $old_suffix;

        my $rule = {
            old_suffix => $old_suffix,
            new_suffix => $new_suffix,
            type => $type,
            exceptions => {},
            exception_type => $exception_type,
        };

        if ($exceptions) {
            $exceptions =~ s/\s//g;
            foreach my $exception (split /,/,$exceptions) {
                $rule->{exceptions}{$exception} = 1;
                #            print "old: $old_suffix EX: $exception\n";
            }
        }

        push @rules, $rule;
    }



    foreach my $lexeme ($dict->get_lexemes) {
        if ( $lexeme->lemma =~ /ost$/ and $lexeme->pos eq 'N'
                 and $lexeme->lemma !~ /\p{IsUpper}/
                     and not $non_deadj{$lexeme->lemma} ) {
            my $orig_source_lexeme = $lexeme->source_lexeme;

            my $success;
            my $msg;
          RULES:
            foreach my $rule (@rules) {
                my $old_suffix = $rule->{old_suffix};
                my $new_suffix = $rule->{new_suffix};
#            print "Trying rule ".$old_suffix."\n";

                my $source_lemma = $lexeme->lemma;
                if ($old_suffix eq 'ičnost') { # this rule is exceptional and must be hardwired (3 types of derivations)
                    if ( $source_lemma =~
                             /^(dědičnost|jednoslabičnost|spolupatřičnost|patřičnost|rozličnost|sličnost|dýchavičnost)$/ ) {
                        $new_suffix = 'ičný';
                    }
                    elsif ( $source_lemma =~ /^(tradičnost|netradičnost|hraničnost|bezhraničnost)$/ ) {
                        $new_suffix = 'iční';
                    }
                    else {
                        $new_suffix = 'ický';
                    }
                }

                elsif ($lexeme->lemma =~ /$old_suffix/ and $rule->{exceptions}{$lexeme->lemma}) {
                    print "EXCEPTION catched: before $new_suffix\t";
                    $new_suffix =~ s/ý$/í/ or $new_suffix =~ s/í$/ý/;
                    print "after: $new_suffix\n";
                }

                if ($source_lemma =~ s/$old_suffix$/$new_suffix/) {
                    my $check_source_lexeme;
                    if ($orig_source_lexeme) {
                        if ($orig_source_lexeme->lemma eq $source_lemma) {
                            $msg =  "SITUATION-1 - unchanged source lemma\t noun=".$lexeme->lemma." JH=rules=".$source_lemma;
                        }
                        else {
                            $msg = "SITUATION-2 - different source lemma\t noun=".$lexeme->lemma
                                ." JH=".$orig_source_lexeme->lemma." rules=$source_lemma";
                            $check_source_lexeme = 1;
                        }
                    }
                    else {
                        $msg = "SITUATION-3 - no source lexeme specified before\t noun=".$lexeme->lemma
                            ." rules=$source_lemma";
                        $check_source_lexeme = 1;
                    }

                    if ($check_source_lexeme) {
                        # TODO: muze jich byt vic
                        my ($new_source_lexeme) = $dict->get_lexemes_by_lemma($source_lemma);
                        if (not $new_source_lexeme) {
                            my @long_lemmas = map { $_->{lemma} } grep {  $_->{tag} =~ /^AAMS1/ } $analyzer->analyze($source_lemma);
                            # TODO: muze jich byt vic, nemusi byt zadny

                            if (@long_lemmas==0 and not acceptable_adj($source_lemma)) {
                                print "ERROR: no analysis for new source lemma $source_lemma\n";
                            }
                            else {
                                $new_source_lexeme = $dict->create_lexeme({
                                    lemma  => $source_lemma,
                                    mlemma => $long_lemmas[0] || $source_lemma,
                                    pos => 'A',
                                    lexeme_origin => 'rules-for-ost',
                                });
                                print "NEW LEXEME CREATED: $source_lemma\n";
                            }

                        }

                        if ($new_source_lexeme) {
                            $dict->add_derivation({
                                source_lexeme => $new_source_lexeme,
                                derived_lexeme => $lexeme,
                                deriv_type => 'A2N',
                                derivation_origin => 'rules-for-ost',
                            });
                        }
                    }

                    $success = 1;
                    last RULES;
                }
            }

            if (not $success) {
                $msg = "SITUATION-0 - no rule applies\t noun=".$lexeme->lemma;
            }

            print "$msg\n";

        }
    }

    return $dict;
}

1;
