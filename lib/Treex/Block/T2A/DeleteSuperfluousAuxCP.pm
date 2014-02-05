package Treex::Block::T2A::DeleteSuperfluousAuxCP;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'override_distance_limit' => ( isa => 'HashRef', is => 'rw', default => sub { {} } );

has 'base_distance_limit' => ( isa => 'Int', is => 'rw', default => 8 );

sub process_tnode {

    my ( $self, $tnode ) = @_;

    # Only work on coordination nodes
    return if !$tnode->is_coap_root();

    # Get AuxCP members of my coordination (must be min. 2)
    my @tmembers = grep { $_->is_member } $tnode->get_children();
    my @auxCP_nodes =
        sort { $a->ord <=> $b->ord }
        grep { ( $_->afun || '' ) =~ /Aux[CP]/ }
        map { $_->get_aux_anodes() }
        @tmembers;
    return if ( !@auxCP_nodes || @auxCP_nodes < 2 );

    # Find those that should be deleted (exclude the first one)
    my $first_auxCP_node = shift @auxCP_nodes;
    my $afun             = $first_auxCP_node->afun;
    my $prev_ord         = $first_auxCP_node->ord;
    my $limit            = $self->override_distance_limit->{ $first_auxCP_node->lemma } // $self->base_distance_limit;

    foreach my $anode (@auxCP_nodes) {
        my $ord = $anode->ord;

        # Keep all AuxCP if some are too far apart from each other
        return if $prev_ord + $limit < $ord;

        # Keep all AuxCP if some have different lemmas
        return if $anode->lemma ne $first_auxCP_node->lemma;
        $prev_ord = $ord;
    }

    # Rehang the first (possibly compound) AuxCP above the coordination (incl. punctuation)
    my $coord_node = $first_auxCP_node->get_parent;
    my $above      = $coord_node->get_parent;
    foreach my $child ( grep { ( $_->afun || '' ) !~ /^($afun|Aux[XG])$/ } $first_auxCP_node->get_children ) {
        $child->set_parent($coord_node);
        $child->set_is_member( $first_auxCP_node->is_member );
    }
    $first_auxCP_node->set_parent($above);
    $first_auxCP_node->set_is_member( $coord_node->is_member );
    $first_auxCP_node->set_clause_number( $coord_node->clause_number );
    $first_auxCP_node->shift_before_subtree( $coord_node ); 
    $coord_node->set_is_member();
    $coord_node->set_parent($first_auxCP_node);

    # Delete the remaining AuxCPs
    my %deleted;
    foreach my $anode (@auxCP_nodes) {

        # Skip already deleted parts of a complex AuxCP
        # TODO this shouldn't be needed (??); an AuxCP CHILD of a complex AuxCP will not get in the @auxCP_nodes array
        next if $deleted{$anode};

        foreach my $child ( $anode->get_children ) {

            # Remove all AuxCP nodes of a complex AuxCP
            if ( ( $child->afun || '' ) eq $afun ) {
                $child->remove();
                $deleted{$child} = 1;
            }
                        
            # Move all regular children upwards
            else {
                $child->set_parent( $anode->get_parent );
                $child->set_is_member( $anode->is_member );
            }
        }

        # Remove the base AuxCP
        $anode->remove();
    }
    return;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::DeleteSuperfluousAuxCP

=head1 DESCRIPTION

In constructions such as 'for X and Y', the second
preposition or subordinate conjunction created on the target side ('for X and for Y')
is removed.

=head1 TODO

Distribute the link in C<aux.rf> to the first preposition for all t-nodes with deleted prepositions. 

=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
