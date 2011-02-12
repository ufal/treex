package SxxT_to_TyyT::Clone_ttree;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub BUILD {
    my ($self) = @_;
    if (not $self->get_parameter('SOURCE_LANGUAGE')
            or not $self->get_parameter('TARGET_LANGUAGE')) {
        Report::fatal "Parameter LANGUAGE must be specified!";
    }
}

sub process_bundle {

    my ( $self, $bundle ) = @_;

    my $source_tree_name = 'S'.$self->get_parameter('SOURCE_LANGUAGE').'T';
    my $target_tree_name = 'T'.$self->get_parameter('TARGET_LANGUAGE').'T';

    my $target_root = $bundle->copy_tree($source_tree_name, $target_tree_name);

    $target_root->set_attr('atree.rf', undef);

    foreach my $node ( $target_root, $target_root->get_descendants ) {

        my $new_id = $node->get_attr('id');
        my $old_id = $new_id;
        $old_id =~ s/$target_tree_name/$source_tree_name/
            or Report::fatal "Cannot find the source-side ID for $new_id";

        $node->set_attr( 'source/head.rf', $old_id );

        # "translating" target ids of coreference links:

        foreach my $list_name ('coref_gram.rf','coref_text.rf') {
            my $coref_list = $node->get_attr($list_name);
            if ($coref_list) {
                $node->set_attr( $list_name,
                                 [ map { s/^$source_tree_name/$target_tree_name/; $_ } @$coref_list ] ) ;
            }
        }

        # 'clone' is a default value of origin
        $node->set_attr( 't_lemma_origin', 'clone' );
        $node->set_attr( 'formeme_origin', 'clone' );

        # removing links to a-layer
        $node->set_attr('a/lex.rf',undef);
        $node->set_attr('a/aux.rf',undef);

    }
}

1;

=over

=item SxxT_to_TyyT::Clone_ttree

Within each bundle, a copy of the source-language t-tree is created and stored as target-language t-tree.
All the node attributes (except identifier and co-reference attributes, which have to be `translated')
are copied without any change.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
