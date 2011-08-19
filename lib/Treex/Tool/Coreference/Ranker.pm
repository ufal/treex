package Treex::Tool::Coreference::Ranker;

use Moose::Role;

has 'model_path' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Str',

    documentation => 'path to the trained model',
);

requires '_build_model';
requires 'rank';


sub pick_winner {
    my ($self, $instances) = @_;

    my $cand_weights = $self->rank( $instances );
    my @cands = sort {$cand_weights->{$b} <=> $cand_weights->{$a}} 
        keys %{$cand_weights};
    return $cands[0];
}

1;

__END__

=head1 NAME

Treex::Tool::Coreference::Ranker

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
