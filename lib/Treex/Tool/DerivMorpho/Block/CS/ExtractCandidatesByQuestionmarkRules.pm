package Treex::Tool::DerivMorpho::Block::CS::ExtractCandidatesByQuestionmarkRules;
use Moose;
use Treex::Tool::DerivMorpho::Block;
extends 'Treex::Tool::DerivMorpho::Block';

use Treex::Core::Log;


my @rule_names = qw(rules-adj rules-subst1 rules-subst2);
my @spellchange_names = qw(spellchanges1 spellchanges2);

my %turns = (
    'adj+spell1+spell2' =>  { rules => [qw(rules-adj)], spell => [qw(spellchanges1 spellchanges2)] },
    'subst1+spell2' =>  { rules => [qw(rules-subst1)], spell => [qw(spellchanges2)] },
    'subst2+spell1+spell2' =>  { rules => [qw(rules-subst2)], spell => [qw(spellchanges1 spellchanges2)] },
);

# load derivation rules

my %rules;
my %spellchanges;
my $maxlimit = 200000000000000000000000;



sub BUILD {
    my $self = shift;

    foreach my $rule_name (qw(rules-adj rules-subst1 rules-subst2)) {

        $rules{$rule_name} = [];

        my $filename = $self->my_directory."manual.ExtractGeneralizedCandidatesByMluv.${rule_name}.tsv";
        print STDERR "Loading $filename\n";
        open my $R, '<:utf8', $filename or die $!;

        my $rule_number;
        while (<$R>) {

            my $lowercase = ($_ =~ /ZMEN/);

            next unless /^([A-Z])\?\t([A-Z])-(\S+)/;

            $rule_number++;
            push @{$rules{$rule_name}}, {
                source_pos => $1,
#                source_suffix => $2,
                target_pos => $2,
                target_suffix => $3,
                lowercase => $lowercase,
            };

            last if $rule_number == $maxlimit;
        }
    }


    # load spellchanges

    foreach my $spellchange_name (qw(spellchanges1 spellchanges2)) {

        $spellchanges{$spellchange_name} = [];
        my $filename = "manual.ExtractGeneralizedCandidatesByMluv.${spellchange_name}.tsv";
        print STDERR "Loading $filename";
        open my $S, '<:utf8', $self->my_directory.$filename or die $!;
        while (<$S>) {
            my ($before,$after) = split /\t/;
            if ($before and $after) {
                push @{$spellchanges{$spellchange_name}},
                    {
                        source => $before,
                        target => $after,
                    };
            }
        }
    }
}



sub process_dictionary {

    my ($self, $dict) = @_;

    foreach my $turn_name (keys %turns) {

        foreach my $rule (map { @{$rules{$_}} } @{$turns{$turn_name}{rules}}) {

            print "$turn_name\n$turn_name\tTRYING TO APPLY RULE $rule->{source_pos}? --> $rule->{target_pos}-$rule->{target_suffix}\n";


          LEXEME:

	    foreach my $source_lexeme ($dict->get_lexemes) {

	        my $source_lemma = $source_lexeme->lemma;

                if ( $source_lexeme->pos eq $rule->{source_pos}  ) {

                  SPELLCHANGE:
                    foreach my $spellchange_rule ( 0, map { @{$spellchanges{$_}} } @{$turns{$turn_name}{spell}}) {

			my $source_lemma_changed = $source_lemma;

			if ($spellchange_rule) {
			  my ($source,$target) = ($spellchange_rule->{source},$spellchange_rule->{target});
			  $source_lemma_changed =~ s/(.)$source/$1$target/ or next SPELLCHANGE;
			}

			my $start_index = length($source_lemma_changed)-4;
			if ($start_index < 3) {
			  $start_index = 3;
			}


		      STEM:
			foreach my $source_lemma_stem ( map {substr($source_lemma_changed,0,$_)}
							( $start_index .. length($source_lemma_changed ))) {

			    my $target_lemma = $source_lemma_stem . $rule->{target_suffix};
			    next if $source_lemma eq $target_lemma;

                            my @target_lexemes = grep {$_->pos eq $rule->{target_pos}}
                                $dict->get_lexemes_by_lemma($target_lemma);


                            foreach my $target_lexeme (@target_lexemes) {
                                print  "$turn_name\t  $source_lemma --> ".$target_lexeme->lemma;
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
        }
    }

    return $dict;

}
