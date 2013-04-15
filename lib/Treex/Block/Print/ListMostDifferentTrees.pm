package Treex::Block::Print::ListMostDifferentTrees;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );
has 'selector2' => ( is => 'rw', isa => 'Str');
has 'selector3' => ( is => 'rw', isa => 'Str');
has 'threshold' => ( is => 'rw', isa => 'Num', default => 0.95);
my $a13 = 0;
my $a23 = 0;
my $tot = 0;

sub process_bundle {
    my ($self, $bundle) = @_;
    my $atree1 = $bundle->get_tree($self->language, 'a', $self->selector);
    my $atree2 = $bundle->get_tree($self->language, 'a', $self->selector2);
    my $atree3 = $bundle->get_tree($self->language, 'a', $self->selector3);
    my @parents1 = map {$_->get_parent->ord} $atree1->get_descendants({ordered=>1});
    my @parents2 = map {$_->get_parent->ord} $atree2->get_descendants({ordered=>1});
    my @parents3 = map {$_->get_parent->ord} $atree3->get_descendants({ordered=>1});
    my $nodes = scalar @parents1;
    return if @parents1 != @parents2 || @parents2 != @parents3;
    my $agree12 = 0;
    my $agree13 = 0;
    my $agree23 = 0;
    foreach my $i (0 .. $nodes - 1) {

        $agree12++ if $parents1[$i] == $parents2[$i];
        $agree13++ if $parents1[$i] == $parents3[$i];
        $agree23++ if $parents2[$i] == $parents3[$i];
    }
    $a13 += $agree13; $a23 += $agree23;
    $tot += $nodes;
    if ($agree12 / $nodes < $self->threshold && $agree13 > $agree23) {
        print $atree1->get_address()."\n";
    }
}

sub process_end {
    print "$a13 $a23\n";
}

1;

=over

=item Treex::Block::Eval::ListMostDifferentTrees;

=back

=cut

# Copyright 2011 David Marecek
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
