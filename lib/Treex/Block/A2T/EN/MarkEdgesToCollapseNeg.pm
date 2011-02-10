package SEnglishA_to_SEnglishT::Mark_edges_to_collapse_neg;

use utf8;
use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $a_root = $bundle->get_tree('SEnglishA');

    foreach my $a_node ( $a_root->get_descendants() ) {
        # Skip nodes that are already marked to be collapsed to parent.
        # Without this check we could rarely create a t-node with no lex a-node.   
        next if $a_node->edge_to_collapse;        
        my ($eparent) = $a_node->get_eff_parents() or next;
        
        my $p_tag = $eparent->tag || '_root';
        my $parent_is_verb = $p_tag =~ /^(V|MD)/;
        if ( $a_node->lemma eq 'not' && $parent_is_verb ) {
            $a_node->set_attr( 'is_auxiliary',     1 );
            $a_node->set_attr( 'edge_to_collapse', 1 );
        }
    }
    return;
}

1;

=over

=item SEnglish_to_SEnglish::Mark_edges_to_collapse_neg

When building the t-layer for purposes of TectoMT transfer,
some additional rules are applied compared to preparing data for annotators.

Currently, there is just one rule for marking word "not" as auxiliary
and collapsing to the governing verb
(grammateme C<negation> will be then used also for verbs).

=back

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
