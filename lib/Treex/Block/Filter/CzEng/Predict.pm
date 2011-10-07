package Treex::Block::Filter::CzEng::Predict;
use Moose;
use Treex::Core::Common;
use Treex::Block::Filter::CzEng::MaxEnt;
use Treex::Block::Filter::CzEng::NaiveBayes;
use Treex::Block::Filter::CzEng::DecisionTree;

extends 'Treex::Block::Filter::CzEng::Common';

has model_file => (
    isa           => 'Str',
    is            => 'ro',
    required      => 0,
    default       => "/net/projects/tectomt_shared/data/models/czeng_filter/model",
    documentation => 'model file'
);

has classifier_type => (
    isa           => 'Str',
    is            => 'ro',
    required      => '1',
    documentation => 'classifier type, can be "maxent", "naive_bayes", "decision_tree"'
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
    } elsif ( $self->{classifier_type} eq "naive_bayes" ) {
        $self->{_classifier_obj} = new Treex::Block::Filter::CzEng::NaiveBayes();
    } elsif ( $self->{classifier_type} eq "decision_tree" ) {
        $self->{_classifier_obj} = new Treex::Block::Filter::CzEng::DecisionTree();
    } else {
        log_fatal "Unknown classifier type: $self->{classifier_type}";
    }
}

sub process_document {
    my ( $self, $document ) = @_;
    $self->{_classifier_obj}->init();
    $self->{_classifier_obj}->load($self->{model_file});

    open( my $anot_hdl, $self->{annotation} ) or log_fatal $!;
    foreach my $bundle ($document->get_bundles()) {
        my @features = $self->get_features($bundle);
        my $prediction = $self->{_classifier_obj}->predict( \@features );

        # some classifiers (at least decision trees) sometimes don't give an answer,
        # let's keep the sentence in such case
        $prediction = 'ok' if ! defined $prediction;

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
