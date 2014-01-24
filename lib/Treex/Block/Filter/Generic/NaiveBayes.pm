package Treex::Block::Filter::Generic::NaiveBayes;
use Moose;
use Treex::Core::Common;
use Algorithm::NaiveBayes;
with 'Treex::Block::Filter::Generic::Classifier';

my $nb;

sub init
{
    $nb = Algorithm::NaiveBayes->new();
}

sub see
{
    $nb->add_instance( attributes => _create_hash($_[1]), label => $_[2] );
}

sub learn
{
    $nb->train();
}

sub predict
{
    my $prediction = $nb->predict( attributes => _create_hash($_[1]) );
    return $prediction->{'x'} > $prediction->{'ok'} ? 'x' : 'ok';
}

sub score
{
    my $prediction = $nb->predict( attributes => _create_hash($_[1]) );
    return $prediction->{'ok'};
}

sub load
{
    $nb = Algorithm::NaiveBayes->restore_state( $_[1] );
}

sub save
{
    $nb->save_state( $_[1] );
}

sub _create_hash
{
    my @array = @{ $_[0] };
    my %hash = map {
        $_ =~ m/=/ ? split '=', $_ : ( $_, 1 )
    } @array;
    return \%hash;
}

1;

=over

=item Treex::Block::Filter::Generic::NaiveBayes

Implementation of 'Classifier' role for naive Bayes model.

=back

=cut

# Copyright 2011, 2014 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
