package Treex::Block::T2A::CopyTtree;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';




sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $document = $bundle->get_document();

    my $source_tree_name = 'T'.$self->get_parameter('LANGUAGE').'T';
    my $target_tree_name = 'T'.$self->get_parameter('LANGUAGE').'A';
    $bundle->copy_tree( $source_tree_name, $target_tree_name );

    my @tnodes = $bundle->get_tree($source_tree_name)->get_descendants({add_self=>1});
    my @anodes = $bundle->get_tree($target_tree_name)->get_descendants({add_self=>1});


    foreach my $i (0..$#anodes) {
        my $anode = $anodes[$i];
        my $tnode = $tnodes[$i];

        my $lemma = $tnode->t_lemma || '';

        if ( $lemma eq '#Cor' ) {
            # Hopefully, there are no children, but..
            foreach my $child ( $anode->get_children() ) {
                $child->set_parent( $anode->get_parent() );
            }
            $anode->disconnect();
        }

        else {

            $tnode->set_attr('a/lex.rf',$anode->get_attr('id'));

            $lemma =~ s/_s[ie]$//g;
            $anode->set_lemma($lemma);
            $anode->set_attr( 'ord',     $anode->ord );

            # set some afuns so _eff_ routines can work
            if ( $tnode->is_coap_root() ) {
                $anode->set_attr( 'afun', $tnode->functor eq 'APPS' ? 'Apos' : 'Coord' );
            }
            if ( defined $tnode->sentmod ) {
                ##$node->set_afun('AuxS');
            }

            #TODO: $bundle->copy_tree( 'TCzechT', 'TCzechA' ) deletes is_member !!!
            if ( $tnode->is_member ) {
                $anode->set_is_member(1) );
            }

            # TODO: vymazat tektogramaticke atributy !!!
        }
    }
    return;
}

1;

=over

=item Treex::Block::T2A::CopyTtree

Within each bundle, a copy of TCzechT tree is created and stored as TCzechA tree.

=back

=cut

# Copyright 2008-2010 Zdenek Zabokrtsky, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
