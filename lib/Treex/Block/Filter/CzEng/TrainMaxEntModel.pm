package Treex::Block::Filter::CzEng::TrainMaxEntModel;
use Moose;
use Treex::Core::Common;
use AI::MaxEntropy;
extends 'Treex::Block::Filter::CzEng::Common';

has outfile => (
    isa => 'Str',
    is => 'ro',
    required => 1,
    documentation => 'output file for the model'
);

sub process_document {
    my ($self, $document) = @_;
    my $model = AI::MaxEntropy->new();

    foreach my $bundle ( $document->get_bundles() ) {
        my @features = $self->get_features($bundle);
        my $annotation = $self->get_annotation($bundle); # TODO implement this
        $model->see(\@features => $annotation);
    }
    
    $model->save($self->outfile);
    return 1;
}

=over

=item Treex::Block::Filter::CzEng::TrainMaxEntModel

Given a manually annotated document and results of all filters,
train a maximum entropy model and store it in 'outfile'.

=back

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
