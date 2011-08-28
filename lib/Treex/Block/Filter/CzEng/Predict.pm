package Treex::Block::Filter::CzEng::Predict;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Filter::CzEng::Common';

has modelfile => (
    isa           => 'Str',
    is            => 'ro',
    required      => 0,
    default       => "/net/projects/tectomt_shared/data/models/czeng_filter/model",
    documentation => 'output file for the model'
);

has classifier_type => (
    isa           => 'Str',
    is            => 'ro',
    required      => '1',
    documentation => 'classifier type, can be "maxent", TODO'
);

has _classifier_obj => (
    is            => 'rw',
    required      => '0',
    does          => 'Treex::Block::Filter::CzEng::Classifier',
);

sub BUILD {
    my $self = shift;
    if ( $self->{classifier_type} eq "maxent" ) {
        $self->{_classifier_obj} = new Treex::Block::Filter::CzEng::MaxEnt();
    } else {
        log_fatal "Unknown classifier type: $self->{classifier_type}";
    }
}

sub process_document {
    my ( $self, $document ) = @_;
    $self->{_classifier_obj}->init();

    open( my $anot_hdl, $self->{annotation} ) or log_fatal $!;
    foreach my $bundle ($document->get_bundles()) {
        my @features = $self->get_features($bundle);
        $self->add_feature($self->{_classifier_obj}->predict( \@features ));
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::Predict

Given a classifier and model, classify bad sentence pairs.

=back

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
