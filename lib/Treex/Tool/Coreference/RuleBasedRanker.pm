package Treex::Tool::Coreference::RuleBasedRanker;

use Moose;
use Treex::Core::Common;

with 'Treex::Tool::ML::Ranker';

sub rank {
    my ($self, $instances, $debug) = @_;

    my $cand_weights;
    my $max_weight = -2;

    foreach my $id (keys %{$instances}) {
        my $instance = $instances->{$id};
        my $cand_weight = 0;
        
        if (($instance->{b_gen_agree} == 1) && ($instance->{b_num_agree} == 1)) {
            
            $cand_weight += 1 if ($instance->{b_cand_subj} == 1);
            #$cand_weight += 1 if (($instance->{b_cand_subj} == 1) && );
            $cand_weight += 1 if ($instance->{r_cand_freq} > 1);
            $cand_weight += 1 if ($instance->{b_cand_akt} == 1);
            $cand_weight += 2 if ($instance->{b_coll} == 1);
            
            if ($instance->{c_sent_dist} == 1) {
                $cand_weight += 1;
            }
            elsif ($instance->{c_sent_dist} == 0) {
                $cand_weight += 2;
            }
        }
        else {
            $cand_weight -= 1;
        }
        if ($cand_weight > $max_weight) {
            $max_weight = $cand_weight;
        }
        
        $cand_weights->{$id} = $cand_weight;
    }

    my @best_ids = grep {$cand_weights->{$_} == $max_weight} keys %$cand_weights;

    if (@best_ids > 1) {
        my ($winner, @rest) = sort {$instances->{$a}->{c_cand_ord} <=> $instances->{$b}->{c_cand_ord}} @best_ids;
        $cand_weights->{$winner} += 1;
    }

    return $cand_weights;
}

1;


__END__

=head1 NAME

Treex::Tool::Coreference::RuleBasedRanker

=head1 DESCRIPTION

A rule based coreference ranker based on the Linh, Žabokrtský (2007) paper.

=head1 METHODS

=over

=item C<rank>

Calculates scores of candidates based on the rules presented in the paper.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz> 

=head1 COPYRIGHT AND LICENCE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
