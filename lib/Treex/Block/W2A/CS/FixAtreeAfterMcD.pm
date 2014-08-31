package Treex::Block::W2A::CS::FixAtreeAfterMcD;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_atree {
    my ( $self, $a_root ) = @_;

    foreach my $a_node ( $a_root->get_descendants ) {
        if ( $a_node->afun eq "AuxX" || $a_node->afun eq "AuxG" ) {
            my @children = $a_node->get_children();
            my $ch       = $children[0];
            if ( defined $ch && $ch->is_member ) {

                # _Co under AuxX => change AuxX to Coord
                $a_node->set_afun('Coord');
            }
        }        
    }

    my @root_children = grep { $_->afun ne "AuxK" } $a_root->get_children;
    foreach my $i ( 1 .. $#root_children ) {
        $root_children[$i]->set_parent( $root_children[0] );
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::W2A::CS::FixAtreeAfterMcD

=head1 DESCRIPTION

Some hardwired fixes of McDonald parser output:

=over 

=item *

AuxG or AuxX above coordinated (is_member) nodes changed to Coord

=item *

McD sometimes generates trees with more then two children
(there should be only one effective root and final punctuation).
If it happens, everything is attached below the first root's child.

=back

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
