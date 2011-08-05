package Treex::Block::Filter::CzEng::MaxEntCombine;
use Moose;
use Treex::Core::Common;
use AI::MaxEntropy;
extends 'Treex::Block::Filter::CzEng::Common';

has modelfile => (
    isa => 'Str',
    is => 'ro',
    required => 0,
    default => "/net/projects/tectomt_shared/data/models/czeng_filter/maxent",
    documentation => 'file that contains a model trained by TrainMaxEntModel'
);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $model = AI::MaxEntropy::Model->new($self->{modelfile});

    my @features = $self->get_features($bundle);
    
    $self->add_feature( $bundle, 'maxent_output=' . $model->predict(\@features) );

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::MaxEntCombine

Add a final accept/reject "feature". TODO filter out rejected sentences instead.

=back

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
