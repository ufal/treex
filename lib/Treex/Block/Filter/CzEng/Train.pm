package Treex::Block::Filter::CzEng::Train;
use Moose;
use Treex::Core::Common;
use AI::MaxEntropy;
use AI::MaxEntropy::Model;
extends 'Treex::Block';

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
    default       => "/net/projects/tectomt_shared/data/models/czeng_filter/maxent",
    documentation => 'output file for the model'
);

has use_for_training => (
    isa           => 'Int',
    is            => 'ro',
    required      => '1'
    documentation => 'how many sentences should be used to train the model (the rest '
                     . 'is used for evaluation)'
);

has classifier => (
    is            => 'rw',
    required      => '1',
    does          => 'Treex::Block::Filter::CzEng::Classifier'
    documentation => 'a specific classifier object (such as MaxEnt)'
);

sub process_document {
    my ( $self, $document ) = @_;
    $self->{classifier}->init();

    # train
    open( my $anot_hdl, $self->{annotation} ) or log_fatal $!;
    my @bundles = $document->get_bundles();
    for ( my $i = 0; $i < $self->{use_for_training}; $i++ ) {
        log_fatal "Not enough sentences for training" if $i >= scalar @bundles;
        my @features = $self->get_features($bundles[$i]);
        my $anot     = <$anot_hdl>;
        $anot = ( split( "\t", $anot ) )[0];
        log_fatal "Error reading annotation file $self->{annotation}" if ! defined $anot;
        $self->{classifier}->see( \@features => $anot );
    }
    $self->{classifier}->learn();
    $self->{classifier}->save( $self->{outfile} );

    # evaluate
    my ( $x, $p, $tp );
    for ( my $i = $self->{use_for_training}; $i < scalar @bundles; $i++ ) {
        my @features = $self->get_features($bundles[$i]);
        my $anot     = <$anot_hdl>;
        $anot = ( split( "\t", $anot ) )[0];
        log_fatal "Error reading annotation file $self->{annotation}" if ! defined $anot;
        $x++ if $anot eq 'x';
        my $prediction = $self->{classifier}->predict( \@features );
        $p++ if $prediction eq 'x';
        $tp++ if $prediction eq $anot;
    }
    log_info sprintf( "Precision = %.03f, Recall = %.03f\n", $tp / $p, $tp / $x );

    return 1;
}

return 1;

=over

=item Treex::Block::Filter::CzEng::Train

Given data and a classifier object, train and evaluate a filter model.

=back

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
