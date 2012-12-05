package Treex::Block::Print::ListMostDifferentTrees;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );
has 'selector2' => ( is => 'rw', isa => 'Str');
has 'threshold' => ( is => 'rw', isa => 'Num', default => 0.95);

sub process_bundle {
    my ($self, $bundle) = @_;
    my $atree1 = $bundle->get_tree($self->language, 'a', $self->selector);
    my $atree2 = $bundle->get_tree($self->language, 'a', $self->selector2);
    my @parents1 = map {$_->get_parent->ord} $atree1->get_descendants;
    my @parents2 = map {$_->get_parent->ord} $atree2->get_descendants;
    return if @parents1 != @parents2;
    my $agree = 0;
    foreach my $i (0 .. $#parents1) {
        $agree++ if $parents1[$i] == $parents2[$i];
    }
    if ($agree / (scalar @parents1) < $self->threshold) {
        print "".$atree1->get_address()."\n";
    }
}

1;

=over

=item Treex::Block::Eval::ListMostDifferentTrees;

=back

=cut

# Copyright 2011 David Marecek
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
