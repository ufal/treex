package Treex::Block::A2W::EN::DeleteTracesFromAtree;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

sub process_zone {
    my ( $self, $zone ) = @_;

    my %a2t;
    foreach my $tnode ( $zone->get_ttree->get_descendants() ) {
        foreach my $anode ( $tnode->get_anodes ) {
            push @{ $a2t{$anode} }, $tnode;
        }
    }
    foreach my $anode ( $zone->get_atree->get_descendants() ) {
        if ( $anode->tag eq '-NONE-' ) {
            if ( $anode->get_attr( 'p_terminal.rf' ) ) {
                my %p_refs = map { $_->get_attr( 'p_terminal.rf' ) => $_ } $anode->get_children;
                if ( %p_refs ) {
                    my $document = $anode->get_document();
                    my $pnode = $document->get_node_by_id( $anode->get_attr( 'p_terminal.rf' ) );
                    my $desc;
                    while ( not $desc ) {
                        $desc = first {
                            my $id = $_->get_attr( 'id' );
                            grep { $_ eq $id } keys %p_refs
                        } $pnode->get_descendants;
                        $pnode = $pnode->get_parent();
                    }

                    my $new_parent = $p_refs{ $desc->get_attr( 'id' ) };
                    $new_parent->set_parent( $anode->get_parent );
                    foreach my $child ( $anode->get_children ) {
                        $child->set_parent( $new_parent );
                    }
                }
            } else {
                foreach my $child ( $anode->get_children ) {
                    $child->set_parent( $anode->get_parent );
                }
            }
            foreach my $tnode ( @{ $a2t{$anode} } ) {
                if ( $tnode->get_lex_anode && $tnode->get_lex_anode eq $anode ) {
                    $tnode->set_lex_anode(undef);
                }
                else {
                    my @new_aux_anodes = grep { $_ ne $anode } $tnode->get_aux_anodes;
                    $tnode->set_aux_anodes(@new_aux_anodes);
                }
            }
            $anode->remove;
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2W::EN::DeleteTracesFromAtree

=head1 DESCRIPTION

Deletes all traces (nodes with tag '-NONE-') from the a-tree.
The lex.rf and aux.rf links from t-tree are also deleted.

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

Josef Toman <toman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
