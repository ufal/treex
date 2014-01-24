package Treex::Block::Filter::Generic::Eval;
use Moose;
use Treex::Core::Common;
use Treex::Block::Filter::Generic::MaxEnt;
use Treex::Block::Filter::Generic::NaiveBayes;
use Treex::Block::Filter::Generic::DecisionTree;

extends 'Treex::Block::Filter::Generic::Common';

has annotation => (
    isa           => 'Str',
    is            => 'ro',
    required      => 1,
    documentation => 'file with lines containing either "x" or "ok" for each sentence'
);

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
    does          => 'Treex::Block::Filter::Generic::Classifier',
);

sub BUILD {
    my $self = shift;
    if ( $self->{classifier_type} eq "maxent" ) {
        $self->{_classifier_obj} = new Treex::Block::Filter::Generic::MaxEnt();
    } elsif ( $self->{classifier_type} eq "naive_bayes" ) {
        $self->{_classifier_obj} = new Treex::Block::Filter::Generic::NaiveBayes();
    } elsif ( $self->{classifier_type} eq "decision_tree" ) {
        $self->{_classifier_obj} = new Treex::Block::Filter::Generic::DecisionTree();
    } else {
        log_fatal "Unknown classifier type: $self->{classifier_type}";
    }

    $self->{model_file} = "/net/projects/tectomt_shared/data/models/czeng_filter/" . $self->{model_file};
}

sub process_document {
    my ( $self, $document ) = @_;
    $self->{_classifier_obj}->init();
    $self->{_classifier_obj}->load($self->{model_file});

    open( my $anot_hdl, $self->{annotation} ) or log_fatal $!;
    my @bundles = $document->get_bundles();
    my ( $x, $p, $tp ) = qw( 0 0 0 );
    for ( my $i = 0; $i < scalar @bundles; $i++ ) {
        my @features = $self->get_features($bundles[$i]);
        chomp( my $anot = <$anot_hdl> );
        $anot = ( split( "\t", $anot ) )[0];
        log_fatal "Error reading annotation file $self->{annotation}" if ! defined $anot;
        my $prediction = $self->{_classifier_obj}->predict( \@features );
        $prediction = 'ok' if ! defined $prediction; # decision trees say nothing unless they know
        if ($anot eq 'x') {
            $x++;
            $tp++ if $prediction eq 'x';
        }
        $p++ if $prediction eq 'x';
    }
    log_info sprintf( "Precision = %.03f, Recall = %.03f", $p ? $tp / $p : 0, $x ? $tp / $x : 0);

    return 1;
}

1;

=over

=item Treex::Block::Filter::Generic::Evaluate

Given data and a classifier object, evaluate a filter model.

=back

=cut

# Copyright 2011, 2014 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
