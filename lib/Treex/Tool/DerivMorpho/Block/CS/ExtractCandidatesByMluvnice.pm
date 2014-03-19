package Treex::Tool::DerivMorpho::Block::CS::ExtractCandidatesByMluvnice;
use Moose;
use Treex::Tool::DerivMorpho::Block;
extends 'Treex::Tool::DerivMorpho::Block';

use Treex::Core::Log;


sub process_dictionary {

    my ($self, $dict) = @_;
    open my $R, '<:utf8', $self->my_directory.'manual.ExtractCandidatesByMluvnice.rules.tsv' or die $!;

    my @rules;
    my $maxlimit = 2000000000000;

    my $rule_number;
    while (<$R>) {

        s/\?/-?/;

        next unless /^([A-Z])-(\S+)\t([A-Z])-(\S+)/;

        $rule_number++;
        push @rules, {
            source_pos => $1,
            source_suffix => $2,
            target_pos => $3,
            target_suffix => $4,
        };
#        print "Rule initialized: $_\n";

        last if $rule_number == $maxlimit;
    }


    my @spellchange_rules;
    open my $S, '<:utf8', $self->my_directory.'manual.ExtractCandidatesByMluvnice.spellingchanges.tsv' or die $!;
    while (<$S>) {
        my ($before,$after) = split /\t/;
        if ($before and $after) {
            push @spellchange_rules,
                {
                    source => $before,
                    target => $after,
                };
        }
    }




  RULE:
    foreach my $rule (@rules) {

        print "\nTRYING TO APPLY RULE $rule->{source_pos}-$rule->{source_suffix} --> $rule->{target_pos}-$rule->{target_suffix}\n";

        foreach my $target_lexeme ($dict->get_lexemes) {

            my ($source_suffix,$target_suffix) = ($rule->{source_suffix},$rule->{target_suffix});

            my $source_lemma_stem = $target_lexeme->lemma;

            if ( $source_lemma_stem =~ s/$target_suffix$//
                     and $target_lexeme->pos eq $rule->{target_pos}   ) {


              SPELLCHANGE:
                foreach my $spellchange_rule ( 0, @spellchange_rules ) {

                    my $source_lemma = $source_lemma_stem;

                    if ($spellchange_rule) {
                        my ($source,$target) = ($spellchange_rule->{source},$spellchange_rule->{target});
                        $source_lemma =~ s/$target/$source/ or next SPELLCHANGE;
                    }

                    $source_lemma .= $source_suffix;


#                print  "  $source_lemma --> ".$target_lexeme->lemma."\n";
                    my @source_lexemes = grep {$_->pos eq $rule->{source_pos}} $dict->get_lexemes_by_lemma($source_lemma);

                    foreach my $source_lexeme (@source_lexemes) {
                        print  "  $source_lemma --> ".$target_lexeme->lemma;
                        if ($spellchange_rule) {
                            print "(CHANGE: $spellchange_rule->{source} -> $spellchange_rule->{target}) ";
                        }
                        if ($target_lexeme->source_lexeme and $target_lexeme->source_lexeme eq $source_lexeme) {
                            print "   (LINK ALREADY PRESENT)";
                        }
                        print "\n";
                    }
                }
            }
        }
    }

    return $dict;

}
