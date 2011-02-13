package TCzechT_to_TCzechA::Add_auxverb_modal;

use utf8;
use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

my %deontmod2modalverb = (
    'poss' => 'moci',
    'vol'  => 'chtít',
    'deb'  => 'muset',
    'hrt'  => 'mít',
    'fac'  => 'moci',
    'perm' => 'moci',
    ##'perm' => 'smět', # 'smet' vadi u might
);

sub process_bundle {
    my ( $self, $bundle ) = @_;

    foreach my $tnode ( $bundle->get_tree('TCzechT')->get_descendants() ) {
        process_tnode($tnode);
    }
    return;
}

sub process_tnode {
    my ($tnode) = @_;

    # Skip nodes with deontic modality undef or 'decl'
    my $deontmod = $tnode->get_attr('gram/deontmod') || '';
    my $modalverb = $deontmod2modalverb{$deontmod};
    return if !$modalverb;

    # Create new a-node
    my $anode = $tnode->get_lex_anode();
    my $new_node = $anode->create_child();
    $new_node->shift_after_node($anode);
    
    # Set its attributes
    $new_node->reset_morphcat();
    $new_node->set_attr( 'm/lemma',         $anode->get_attr('m/lemma') );
    $new_node->set_attr( 'm/form',          $anode->get_attr('m/form') );
    $new_node->set_attr( 'morphcat/pos',    'V' );
    $new_node->set_attr( 'morphcat/subpos', 'f' );

    # negace bude orisek, zatim zustava u vyznamoveho
    $new_node->set_attr( 'morphcat/negation', 'A' );

    $anode->set_attr( 'm/lemma', $modalverb );
    $anode->set_attr( 'm/form',  undef );

    $tnode->add_aux_anodes( $new_node );
    return;
}

1;

=over

=item TCzechT_to_TCzechA::Add_auxverb_modal

Add a new a-node which represents a model verb accordingly
to the value of the C<deontmod> attribute.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
