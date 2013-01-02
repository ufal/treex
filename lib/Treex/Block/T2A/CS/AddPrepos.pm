package Treex::Block::T2A::CS::AddPrepos;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $formeme = $tnode->formeme;

    return if !defined $formeme || $formeme !~ /^(n|adj):(.+)[+]/;
    my ( $sempos, $prep_forms_string ) = ( $1, $2 );
    my $anode = $tnode->get_lex_anode();

    # Skip weird t-nodes with no lex_anode
    next if !defined $anode;

    # Occasionally there may be more than one preposition (e.g. na_rozdíl_od)
    my @prep_forms = split /_/, $prep_forms_string;

    # Create new nodes for all prepositions.
    # Put them before $anode's subtree (in right word order)
    my @prep_nodes = reverse map { _new_prep_node( $anode, $_ ) } reverse @prep_forms;

    # Hang the last preposition on anode's parent
    my $last_prep = $prep_nodes[-1];
    $last_prep->set_parent( $anode->get_parent() );

    # Hang other prepositions on the last one
    for my $i ( 0 .. ( $#prep_nodes - 1 ) ) {
        $prep_nodes[$i]->set_parent($last_prep);
    }

    # Rehang anode under the last preposition
    $anode->set_parent($last_prep);

    # $anode is now under $last_prep, so attribute is_member
    # moves also to the upper node. (We are in TectoMT, not PDT.)
    $last_prep->set_is_member( $anode->is_member );

    ######
#    my $parent = $anode->get_parent();
#    foreach my $prep (@prep_nodes){
#        $prep->set_parent($parent);
#        $parent = $prep;
#    }
#    $anode->set_parent($prep_nodes[-1]);
#    $prep_nodes[0]->set_is_member($anode->is_member);
    ######
    $anode->set_is_member(undef);

    # Add all prepositions to a/aux.rf of the tnode
    $tnode->add_aux_anodes(@prep_nodes);

    # moving leading adverbs in front of the prepositional group ('v zejmena USA' --> 'zejmena v USA')
    # but keeping some adverbs that relate to numerals ('na téměř XXX milionů dolarů' etc.)
    my $t_first = $tnode->get_children( { preceding_only => 1, first_only => 1 } );
    if ($formeme =~ /^n/
        && defined $t_first
        && ($t_first->functor eq 'RHEM' || $t_first->formeme =~ /^adv/)
        && $t_first->get_lex_anode
        && !($prep_forms_string eq 'na' && $t_first->t_lemma =~ /^(téměř|kolem|okolo|zhruba)$/)
        )
    {
        $t_first->get_lex_anode->shift_before_node( $prep_nodes[0] );
    }

    return;
}

sub _new_prep_node {
    my ( $parent, $form ) = @_;
    my $prep_node = $parent->create_child(
        {   'lemma'        => $form,
            'form'         => $form,
            'afun'         => 'AuxP',
            'morphcat/pos' => 'R',
        }
    );
    $prep_node->shift_before_subtree($parent);
    return $prep_node;
}

1;

=over

=item Treex::Block::T2A::CS::AddPrepos

Add preposition a-nodes (accordingly to the corresponding t-node's formeme).

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
