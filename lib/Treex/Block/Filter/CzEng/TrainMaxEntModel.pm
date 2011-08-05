package Treex::Block::Filter::CzEng::TrainMaxEntModel;
use Moose;
use Treex::Core::Common;
use AI::MaxEntropy;
use AI::MaxEntropy::Model;
extends 'Treex::Block::Filter::CzEng::Common';

has annotation => (
    isa => 'Str',
    is => 'ro',
    required => 1,
    documentation => 'file with lines containing either "x" or "ok" for each sentence'
);

has outfile => (
    isa => 'Str',
    is => 'ro',
    required => 0,
    default => "/net/projects/tectomt_shared/data/models/czeng_filter/maxent",
    documentation => 'output file for the model'
);

sub process_document {
    my ($self, $document) = @_;
    my $maxent = AI::MaxEntropy->new();

    open (my $anot_hdl, $self->{annotation}) or log_fatal $!;
    foreach my $bundle ( $document->get_bundles() ) {
        my @features = $self->get_features($bundle);
        my $anot = <$anot_hdl>;
        $anot = ( split("\t", $anot) )[0];
        log_fatal "Error reading annotation file $self->{annotation}" if ! defined $anot;

        $maxent->see(\@features => $anot);
    }
    my $model = $maxent->learn();
    
    $model->save($self->{outfile});
    return 1;
}

return 1;
=over

=item Treex::Block::Filter::CzEng::TrainMaxEntModel

Given a manually annotated document and results of all filters,
train a maximum entropy model and store it in 'outfile'.

=back

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
