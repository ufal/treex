package Treex::Block::Filter::CzEng::Score;
use Moose;
use Treex::Core::Common;
use Treex::Block::Filter::CzEng::MaxEnt;
use Treex::Block::Filter::CzEng::NaiveBayes;
use Treex::Block::Filter::CzEng::DecisionTree;

extends 'Treex::Block::Filter::CzEng::Common';

has model_file => (
    isa           => 'Str',
    is            => 'rw',
    required      => 0,
    default       => "model.maxent",
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

    $self->{model_file} = "/net/projects/tectomt_shared/data/models/czeng_filter/" . $self->{model_file};
}

sub process_document {
    my ( $self, $document ) = @_;
    $self->{_classifier_obj}->init();
    $self->{_classifier_obj}->load($self->{model_file});

    foreach my $bundle ($document->get_bundles()) {
        my @features = $self->get_features($bundle);
        my $score = $self->{_classifier_obj}->score( \@features );
        $self->add_feature( $bundle, "filter_score=$score" );
    }

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::Score

Given a classifier and model, classify bad sentence pairs.

=back

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
