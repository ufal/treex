package Treex::Block::Filter::CzEng::MaxEnt;
use Moose;
use Treex::Core::Common;
with 'Treex::Block::Filter::CzEng::Classifier';

my ( $maxent, $model );

sub init
{
    $maxent = AI::MaxEntropy->new();
}

sub see
{
    $maxent->see( $_[0] => $_[1] );
}

sub learn
{
    $model = $maxent->learn();
}

sub predict
{
    return $model->predict( $_[0] );
}

sub load
{
    if (defined $model) {
        $model->load( $_[0] );
    } else {
        $model = AI::MaxEntropy::Model->new( $_[0] );
    }
}

sub save
{
    $model->save( $_[0] );
}

1;

=over

=item Treex::Block::Filter::CzEng::MaxEnt

Implementation of 'Classifier' role for maximum entropy model.

=back

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
