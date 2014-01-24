package Treex::Block::Filter::Generic::MaxEnt;
use Moose;
use Treex::Core::Common;
use AI::MaxEntropy;
use AI::MaxEntropy::Model;
use ProbUtils::Normalize;
with 'Treex::Block::Filter::Generic::Classifier';

my ( $maxent, $model );

sub init
{
    $maxent = AI::MaxEntropy->new();
}

sub see
{
    $maxent->see( $_[1] => $_[2] );
}

sub learn
{
    $model = $maxent->learn();
}

sub predict
{
    return $model->predict( $_[1] );
}

sub score
{
    my $ok_score = $model->score( $_[1] => "ok" );
    my $x_score = $model->score( $_[1] => "x" );
    return ( ProbUtils::Normalize::logscores2probs( $ok_score, $x_score ) )[ 0 ];
}

sub load
{
    if (defined $model) {
        $model->load( $_[1] );
    } else {
        $model = AI::MaxEntropy::Model->new( $_[1] );
    }
}

sub save
{
    $model->save( $_[1] );
}

1;

=over

=item Treex::Block::Filter::Generic::MaxEnt

Implementation of 'Classifier' role for maximum entropy model.

=back

=cut

# Copyright 2011, 2014 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
