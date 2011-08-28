package Treex::Block::Filter::CzEng::Train;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has annotation => (
    isa           => 'Str',
    is            => 'ro',
    required      => 1,
    documentation => 'file with lines containing either "x" or "ok" for each sentence'
);

has outfile => (
    isa           => 'Str',
    is            => 'ro',
    required      => 0,
    default       => "/net/projects/tectomt_shared/data/models/czeng_filter/model",
    documentation => 'output file for the model'
);

has use_for_training => (
    isa           => 'Int',
    is            => 'ro',
    required      => '1',
    documentation => 'how many sentences should be used to train the model (the rest '
                     . 'is used for evaluation)'
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
        $self->{_classifier_obj} = Treex::Block::Filter::CzEng::MaxEnt()->new();
    } elsif ( $self->{classifier_type} eq "naive_bayes" ) {
        $self->{_classifier_obj} = Treex::Block::Filter::CzEng::NaiveBayes()->new();
    } elsif ( $self->{classifier_type} eq "decision_tree" ) {
        $self->{_classifier_obj} = Treex::Block::Filter::CzEng::DecisionTree()->new();
    } else {
        log_fatal "Unknown classifier type: $self->{classifier_type}";
    }
}

sub process_document {
    my ( $self, $document ) = @_;
    $self->{_classifier_obj}->init();

    # train
    open( my $anot_hdl, $self->{annotation} ) or log_fatal $!;
    my @bundles = $document->get_bundles();
    for ( my $i = 0; $i < $self->{use_for_training}; $i++ ) {
        log_fatal "Not enough sentences for training" if $i >= scalar @bundles;
        my @features = $self->get_features($bundles[$i]);
        my $anot     = <$anot_hdl>;
        $anot = ( split( "\t", $anot ) )[0];
        log_fatal "Error reading annotation file $self->{annotation}" if ! defined $anot;
        $self->{_classifier_obj}->see( \@features => $anot );
    }
    $self->{_classifier_obj}->learn();
    $self->{_classifier_obj}->save( $self->{outfile} );

    # evaluate
    my ( $x, $p, $tp );
    for ( my $i = $self->{use_for_training}; $i < scalar @bundles; $i++ ) {
        my @features = $self->get_features($bundles[$i]);
        my $anot     = <$anot_hdl>;
        $anot = ( split( "\t", $anot ) )[0];
        log_fatal "Error reading annotation file $self->{annotation}" if ! defined $anot;
        $x++ if $anot eq 'x';
        my $prediction = $self->{_classifier_obj}->predict( \@features );
        $p++ if $prediction eq 'x';
        $tp++ if $prediction eq $anot;
    }
    log_info sprintf( "Precision = %.03f, Recall = %.03f", $tp / $p, $tp / $x );

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::Train

Given data and a classifier object, train and evaluate a filter model.

=back

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
