package SEnglishT_to_TCzechT::Rehang_to_eff_parents;

use 5.008;
use strict;
use warnings;
use utf8;
use Readonly;

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $root = $bundle->get_tree('TCzechT');
    my @nodes = $root->get_descendants();
    
    # Array of first effective parents of every node
    my @eff_parents = map {my ($ep) = $_->get_eff_parents(); $ep} @nodes;
    
    foreach my $i (0 .. $#nodes){
        my $node = $nodes[$i];
        my $ep = $eff_parents[$i];
        my $parent = $node->get_parent();
        next if $parent eq $ep;
        $node->set_deref_attr('original_parent.rf', $parent);
        $node->set_parent($ep);
    }
    
    return;
}

1;
__END__

=over

=item SEnglishT_to_TCzechT::Rehang_to_eff_parents

Rehangs each node to its first effective parent.
If this effective parent is different from the topological parent,
id of the topological parent is saved to the C<original_parent.rf> attribute.
Use L<SEnglishT_to_TCzechT::Rehang_to_orig_parents> to undo all changes.

=back

=cut

# Copyright 2008 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
