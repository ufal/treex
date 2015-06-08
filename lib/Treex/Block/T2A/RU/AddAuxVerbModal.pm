package Treex::Block::T2A::RU::AddAuxVerbModal;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


my %deontmod2modalverb = (
    'poss' => 'мочь',
    'vol'  => 'хотеть',
    'deb'  => 'надо', #here should be on dolzhe/ona dolzhna, but not sure where to get the gender?
    'hrt'  => 'надо',#the same as deb
    'fac'  => 'мочь', 
    'perm' => 'мочь', 
);

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # Skip nodes with deontic modality undef or 'decl'
    my $deontmod = $tnode->gram_deontmod || '';
    my $modalverb = $deontmod2modalverb{$deontmod};
    return if !$modalverb;

    # Create new a-node
    my $anode    = $tnode->get_lex_anode() or return;
    my $new_node = $anode->create_child();
    $new_node->shift_after_node($anode);

    # Set its attributes
    $new_node->reset_morphcat();
    $new_node->set_lemma( $anode->lemma );
    $new_node->set_form( $anode->form );
    $new_node->set_attr( 'morphcat/pos',    'V' );
    $new_node->set_attr( 'morphcat/subpos', 'f' );
    $new_node->set_afun( 'Obj' );


    # negace bude orisek, zatim zustava u vyznamoveho
    $new_node->set_attr( 'morphcat/negation', 'A' );

    $anode->set_lemma($modalverb);
    $anode->set_form(undef);


    $tnode->add_aux_anodes($new_node);


    return;

}

1;

=over

=item Treex::Block::T2A::RU::AddAuxVerbModal

Add a new a-node which represents a model verb accordingly
to the value of the C<deontmod> attribute.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
