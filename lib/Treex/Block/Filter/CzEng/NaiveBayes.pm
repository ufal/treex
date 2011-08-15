package Treex::Block::Filter::CzEng::NaiveBayes;
use Moose;
use Treex::Core::Common;
use Algorithm::NaiveBayes;
with 'Treex::Block::Filter::CzEng::Classifier';

my $nb;

sub init
{
    $nb = Algorithm::NaiveBayes->new();
}

sub see
{
    $nb->add_instance( attributes => %{ _create_hash($_[0]) }, label => $_[1] );
}

sub learn
{
    $nb->train();
}

sub predict
{
    return $nb->predict( attributes => %{ _create_hash($_[0]) } );
}

sub load
{
    $nb = Algorithm::NaiveBayes->restore_state( $_[0] );
}

sub save
{
    $nb->save_state( $_[0] );
}

sub _create_hash
{
    my @array = @{ $_[0] };
    my %hash = map { split '=', $_ } @array;
    return \%hash;
}

1;

=over

=item Treex::Block::Filter::CzEng::NaiveBayes

Implementation of 'Classifier' role for naive Bayes model.

=back

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
