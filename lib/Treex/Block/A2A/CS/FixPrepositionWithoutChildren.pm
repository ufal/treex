package Treex::Block::A2A::CS::FixPrepositionWithoutChildren;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    my $node = $dep;
    if (
        $node->afun eq 'AuxP'
        && !$node->get_children
        && $self->en($node)
        && $self->en($node)->get_children
        )
    {
        if ( $node->get_parent && ( $node->get_parent )->afun eq 'AuxP' ) {
            return;
        }
        foreach my $en_child ( $self->en($node)->get_children ) {
            my ( $nodes, $types ) = $en_child->get_aligned_nodes;

            #if (!$nodes) { return; }
            my @cs_children = $$nodes[0];
            my $cs_child    = $cs_children[0];
            if ( !$cs_child ) { return; }

            $self->logfix1( $cs_child, "PrepositionWithoutChildren" );

            if ( $node->is_descendant_of($cs_child) ) {

                #inverted, $cs_child should be descendant of preposition $node
                $node->set_parent( $cs_child->get_parent );
            }
            $cs_child->set_parent($node);
            $self->logfix2($cs_child);
        }
    }
}

1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixPrepositionWithoutChildren

=head1 DESCRIPTION

Fixing preposition with no children.

=head1 AUTHORS

David Mareček <marecek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2.
See $TMT_ROOT/README for details on Treex licencing.
