package Treex::Block::A2A::CopyNodesFromAlignment;

use Moose;
use Treex::Core::Common;
use Treex::Block::A2A::CopySurfaceFromAlignment;

extends 'Treex::Core::Block';

has '_back_align' => ( isa => 'HashRef', is => 'rw', writer => '_set_back_align' );

has 'reference_language' => ( is => 'ro', isa => 'Treex::Type::LangCode', lazy_build => 1 );
has 'reference_selector' => ( is => 'ro', isa => 'Treex::Type::Selector', default => 'ref' );

sub _build_reference_language {
    my ($self) = @_;
    return $self->language;
}

sub process_atree {

    my ( $self, $aroot ) = @_;
 
    my @anodes = $aroot->get_descendants();
    my $align_root = $aroot->get_bundle()->get_zone( $self->reference_language, $self->reference_selector )->get_atree();
    
    log_fatal( 'Cannot find zone: ' . $self->reference_language . '_' . $self->reference_selector ) if (!$align_root);

    # Find back-alignment links
    $self->_set_back_align( {} );
    $self->_back_align->{$align_root} = $aroot;

    foreach my $anode (@anodes) {
        my $aligned = Treex::Block::A2A::CopySurfaceFromAlignment::_get_aligned_node($anode);
        if ($aligned) {
            $self->_back_align->{$aligned} = $anode if ( !$self->_back_align->{$aligned} );
        }
    }

    # Delete non-aligned nodes
    map { $self->_delete_if_no_aligned($_) } @anodes;
    # Add non-aligned nodes from the other side (we cannot do anything if we don't actually have anything in the tree)
    map { $self->_add_if_no_aligned($_) } $align_root->get_children();
}

# Delete a node if it has no aligned counterpart in the aligned tree
sub _delete_if_no_aligned {

    my ( $self, $anode ) = @_;
    my $aligned = Treex::Block::A2A::CopySurfaceFromAlignment::_get_aligned_node($anode);

    # delete a-nodes that are not in the aligned tree (including superfluous ones if multiple nodes are aligned to one node)
    if ( !$aligned || ( $self->_back_align->{$aligned} != $anode ) ) {

        my $parent = $anode->get_parent();                              # move their children under their parent
        map { $_->set_parent($parent) } $anode->get_children();

        $anode->remove();
        return;
    }
}

# Add nodes from the aligned tree for which there is no counterpart in this tree
sub _add_if_no_aligned {

    my ( $self, $anode ) = @_;

    if ( !$self->_back_align->{$anode} ) {    # add subtrees that are in the aligned tree, but not here

        my $parent = $anode->get_parent();
        my $align  = $self->_back_align->{$parent};

        my $child = $align->create_child();
        $anode->copy_attributes($child);

        $self->_back_align->{$anode} = $child;
    }

    map { $self->_add_if_no_aligned($_) } $anode->get_children();
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2A::CopyNodesFromAlignment

=head1 DESCRIPTION

This block works on an a-tree which is monolingually aligned to another a-tree (used for "silver" generated
a-tree aligned to an automatic analysis tree).

It deletes all nodes from the a-tree that are not aligned to any node in the other tree and copies nodes 
from the other tree which are not aligned to any node in this tree.

=head1 TODO

Delete obsolete back alignment code.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
