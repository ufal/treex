package Treex::Block::A2A::CopyNodesFromAlignment;

use Moose;
use Treex::Core::Common;
use Treex::Block::A2A::CopySurfaceFromAlignment;

extends 'Treex::Core::Block';

has '_back_align' => ( isa => 'HashRef', is => 'rw', writer => '_set_back_align' );

# this whole thing wouldn't be needed if we had back links
has '_a2t' => ( isa => 'HashRef', is => 'rw', writer => '_set_a2t' );

sub _init_a2t {

    my ( $self, $troot ) = @_;

    foreach my $tnode ( $troot->get_descendants() ) {
        foreach my $anode ( $tnode->get_anodes() ) {
            $self->_a2t->{$anode} = $tnode;
        }
    }
}

sub process_atree {

    my ( $self, $aroot ) = @_;

    $self->_set_a2t( {} );    # TODO delete this if we have back links
    if ( $aroot->get_zone->get_ttree ) {
        $self->_init_a2t( $aroot->get_zone->get_ttree );
    }

    my @anodes = $aroot->get_descendants();
    $self->_set_back_align( {} );
    my $align_root;

    foreach my $anode (@anodes) {
        my $aligned = Treex::Block::A2A::CopySurfaceFromAlignment::_get_aligned_node($anode);
        if ($aligned) {
            $self->_back_align->{$aligned} = $anode if ( !$self->_back_align->{$aligned} );
            if ( !$align_root ) {
                $align_root = $aligned->get_root();
                $self->_back_align->{$align_root} = $aroot;
            }
        }
    }

    map { $self->_delete_if_no_aligned($_) } @anodes;
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

        if ( $self->_a2t->{$anode} ) {
            my $tnode = $self->_a2t->{$anode};
            if ( $anode == $tnode->get_lex_anode() ) {
                $tnode->set_lex_anode(undef);
            }
            else {
                $tnode->remove_aux_anodes($anode);
            }
        }
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


=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
