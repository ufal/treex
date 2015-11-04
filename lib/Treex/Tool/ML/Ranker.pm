package Treex::Tool::ML::Ranker;

use Moose::Role;

requires 'rank';


sub pick_winner {
    my ($self, $instances, $debug) = @_;

    my @cand_weights = $self->rank( $instances );
    # DEBUG
    #my $cand_weights = $self->rank( $instances, $debug );
    
    # DEBUG
    #if ($debug) {
    #    print STDERR join "\n", @cand_weights;
    #    print STDERR "\n";
    #}

    my $max_weight;
    my $max_idx;
    for (my $i = 0; $i < @cand_weights; $i++) {
        if (!defined $max_weight || $cand_weights[$i] > $max_weight) {
            $max_weight = $cand_weights[$i];
            $max_idx = $i;
        }
    }
    return $max_idx;
}

1;

__END__

=head1 NAME

Treex::Tool::ML::Ranker

=head1 DESCRIPTION

Role for rankers. Every ML method which ranks instances should implement this
role. This role is not meant just for coreference.

=head1 PARAMETERS

=over

=item C<model_path>

A path to the trained model for ranker.

=back

=head1 METHODS

=over

=item C<pick_winner>

Based on the ranking of candidates returned from the method C<rank>, this
method picks and returns a candidate with the highest score. Input parameter
is a hash of candidates indexed by their ids.

=back

=head1 REQUIRED METHODS

=over

=item C<_build_model>

A private model constructor. Its implementation should build and return a
in-memory representation of the model as a reference to a hash indexed by
strings. The model can be loaded from the C<model_path> file.

=item C<rank>

This method receives a hash of candidates indexed by their ids. They should be
ranked and the result must be a hash with scores indexed by candidates' ids.

=back

=head1 SYNOPSIS

  package Treex::Tool::Coreference::PerceptronRanker;
  use Moose;
  with 'Treex::Tool::Coreference::Ranker';


=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz> 

=head1 COPYRIGHT AND LICENCE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
