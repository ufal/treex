package Treex::Block::Test::ValidReferences;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $document = $bundle->get_document;

    foreach my $zone ($bundle->get_all_zones) {
        foreach my $layer ('a','t','n') {
            if ($zone->has_tree($layer)) {
                foreach my $node
                    ($zone->get_tree($layer)->get_descendants({add_self=>1})) {
                    $self->_check_node($node,$layer);
                }
            }
        }
    }
}

sub _check_reference {
    my ( $self, $node, $attr_name, $refid ) = @_;
    if (not $node->get_document->id_is_indexed($refid)) {
        log_info "Attribute '$attr_name' in node '".$node->id."' contains a reference to a non-existent ID '$refid'";
    }
}


sub _check_node {
    my ( $self, $node, $layer ) = @_;

    if ($layer eq 'a') {
        foreach my $attr_name ('giza_scores/counterpart.rf','ptree.rf','s.rf','p_terminal.rf') {
            if (defined $node->get_attr($attr_name)) {
                $self->_check_reference($node,$attr_name,$node->get_attr($attr_name));
            }
        }
        foreach my $align (@{$node->get_attr('alignment') || []}) {
            $self->_check_reference($node,'align/*/counterpart.rf',$align->{'counterpart.rf'});
        }
    }

    if ($layer eq 't') {
        foreach my $attr_name ('atree.rf','src_tnode.rf','a/lex.rf') {
            if (defined $node->get_attr($attr_name)) {
                $self->_check_reference($node,$attr_name,$node->get_attr($attr_name));
            }
        }

        foreach my $list_attr('compl.rf', 'coref_text.rf', 'coref_gram.rf', 'a/aux.rf') {
            foreach my $refid (@{$node->get_attr($list_attr) || []}) {
                $self->_check_reference($node,$list_attr,$refid);
            }
        }
    }

}


1;

=over

=item Treex::Block::Test::ValidReferences

Check that PMLREF attributes from a-nodes and t-nodes refer only to IDs existing within
the same document.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

