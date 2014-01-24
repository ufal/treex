package Treex::Block::Filter::Generic::DecisionTree;
use Moose;
use Storable;
use Treex::Core::Common;
use AI::DecisionTree;
with 'Treex::Block::Filter::Generic::Classifier';

my $dtree;

sub init
{
    $dtree = AI::DecisionTree->new( noise_mode => 'pick_best');
}

sub see
{
    $dtree->add_instance( attributes => _create_hash($_[1]), result => $_[2] );
}

sub learn
{
    $dtree->train();
}

sub predict
{
    return $dtree->get_result( attributes => _create_hash($_[1]) );
}

sub score
{
    my ( $self, $values_ref );

    # not very useful in this case
    my $prediction = $self->predict( $values_ref );
    if (! defined( $prediction ) || $prediction eq 'ok') {
        return 1;
    } else {
        return 0;
    }
}

sub load
{
    $dtree = retrieve($_[1]) or log_fatal "Unable to load file $_[1]";
}

sub save
{
#    print STDERR join "\n", $dtree->rule_statements();
    $dtree->do_purge();
    store($dtree, $_[1]);
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

=item Treex::Block::Filter::Generic::DecisionTree

Implementation of 'Classifier' role for naive Bayes model.

=back

=cut

# Copyright 2011, 2014 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
