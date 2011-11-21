package Treex::Block::Filter::CzEng::MarkBadPairs;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::Filter::CzEng::Common';

has threshold => (
    isa           => 'Num',
    is            => 'rw',
    required      => 0,
    default       => '0.3',
    documentation => 'threshold for accepting of sentence pairs'
);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my ( $score ) = grep { $_ =~ m/filter_score/ } $self->get_features($bundle);
    $score =~ s/filter_score=//;
    $bundle->wild->{to_delete} = 1 if $score < $self->{threshold};
}

1;

=over

=item Treex::Block::Filter::CzEng::MarkBadPairs

Mark sentence pairs with score below the threshold as 'to_delete' in <wild>.

=back

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
