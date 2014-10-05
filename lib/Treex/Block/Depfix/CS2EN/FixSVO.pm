package Treex::Block::Depfix::CS2EN::FixSVO;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::Depfix::CS2EN::Fix';

sub fix {
    my ( $self, $child, $parent, $al_child, $al_parent ) = @_;

    if (!$parent->is_root
        && $parent->tag =~ /^V/
        && defined $al_child
    ) {

        if ( $child->follows($parent) && $al_child->afun eq 'Sb' ) {
            # VS -> SV
            $self->logfix1($child, "move Sb before verb");
            $self->shift_subtree_before_node($child, $parent);
            $self->logfix2($child);
        } elsif ( $child->precedes($parent) && $al_child->afun eq 'Obj' ) {
            # OV -> VO
            $self->logfix1($child, "move Obj after verb");
            $self->shift_subtree_after_node($child, $parent);
            $self->logfix2($child);
        }
    }
    
    return;
}


1;

=head1 NAME 

Treex::Block::Depfix::CS2EN::FixSVO -- reorder the English sentence so that it has the subject-object-verb ordering.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

