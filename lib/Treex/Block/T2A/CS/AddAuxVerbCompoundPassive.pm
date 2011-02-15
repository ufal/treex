package Treex::Block::T2A::CS::AddAuxVerbCompoundPassive;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';




sub process_tnode {
    my ($self, $t_node) = @_;
    return if ( $t_node->voice || '' ) ne 'passive';
    my $a_node = $t_node->get_lex_anode();

    # $a_node is now the passive autosemantic verb,
    # but we will "move" that word to $new_node (its child) and
    # place auxiliary "být" to $a_node instead.
    # $new_node will be affirmative (possible negation is left in $a_node).
    # $new_node will follow the $a_node.
    my $new_node = $a_node->create_child();
    $new_node->shift_after_node($a_node);

    $new_node->reset_morphcat();
    $new_node->set_lemma($a_node->lemma );
    $new_node->set_form($a_node->form );
    $new_node->set_attr( 'morphcat/gender',   $a_node->get_attr('morphcat/gender') );
    $new_node->set_attr( 'morphcat/number',   $a_node->get_attr('morphcat/number') );
    $new_node->set_attr( 'morphcat/pos',      'V' );
    $new_node->set_attr( 'morphcat/negation', 'A' );
    $new_node->set_attr( 'morphcat/subpos',   's' );
    $new_node->set_attr( 'morphcat/voice',    'P' );

    # $a_node is now auxiliary "být" and governs the autosemantic verb
    $a_node->set_lemma('být');
    $a_node->set_attr( 'morphcat/voice', 'A' );
    $a_node->set_afun('AuxV');

    # Add a link (aux.rf) from the t-layer node to $new_node.
    $t_node->add_aux_anodes($new_node);

    # See next comment
    #$t_node->add_aux_anodes($a_node);
    #$t_node->set_lex_anode($new_node);

    return;
}

# In the current implementation, a/aux.rf goes to autosemantic (main) verb,
# whereas a/lex.rf to the auxiliary verb "být". This isn't optimal, but
# there are no problems with this yet (since we are on the target side).
# The problem is that following blocks that handle future/past tense or generate
# word forms traverse t-trees and use a/lex.rf to find corresponding a-nodes,
# but in case of passives, they should process the auxiliary "být".
# Next code was an attemt to have correct a/lex.rf.
sub process_tnode_AbandonedAlternative {
    my ($t_node) = @_;
    return if ( $t_node->voice || '' ) ne 'passive';
    my $a_node = $t_node->get_lex_anode();

    # Create new node $byt_node for auxiliary verb "být".
    # It should govern the original $a_node and all its children.
    my $byt_node = $a_node->get_parent()->create_child;
    $a_node->set_parent($byt_node);

    foreach my $child ( $a_node->get_children() ) {
        $child->set_parent($byt_node);
    }
    $byt_node->set_attr( 'id', $a_node->generate_new_id() );

    # Add a link (aux.rf) from the t-layer node to auxiliary $byt_node.
    $t_node->add_aux_anodes($byt_node);

    # Place $byt_node just in front of $a_node and fill all values needed.
    $byt_node->shift_before_node( $a_node, { without_children => 1 } );
    $byt_node->reset_morphcat();
    $byt_node->set_lemma('být');
    $byt_node->set_attr( 'morphcat/voice', 'A' );
    $byt_node->set_attr( 'morphcat/pos',   'V' );
    foreach my $cat (qw(negation gender number tense)) {
        $byt_node->set_attr( "morphcat/$cat", $a_node->get_attr("morphcat/$cat") );
    }

    # Change/fill some morphological categories of the original $a_node.
    # Negation is pronounced by the $byt_node and $a_node must be affirmative.
    $a_node->set_attr( 'morphcat/negation', 'A' );
    $a_node->set_attr( 'morphcat/subpos',   's' );
    $a_node->set_attr( 'morphcat/voice',    'P' );

    return;
}

1;

__END__

=encoding utf8

=over

=item Treex::Block::T2A::CS::AddAuxVerbCompoundPassive

Add auxiliary 'být' (to be) a-node in the case of
compound passive verb forms.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
