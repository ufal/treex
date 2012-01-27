package Treex::Block::A2T::CS::MarkEdgesToCollapse;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
use utf8;

sub process_anode {
    my ( $self, $a_node ) = @_;

    my $parent = $a_node->get_parent();

    # default values
    $a_node->set_edge_to_collapse(0);
    $a_node->set_is_auxiliary(0);

    # No node (except AuxK = terminal punctuation: ".?!")
    # can collapse to a technical root.
    if ( $parent->is_root() ) {
        if ( $a_node->afun eq 'AuxK' ) {
            $a_node->set_edge_to_collapse(1);
            $a_node->set_is_auxiliary(1);
        }
    }

    # Should collapse to parent because the $node is auxiliary?
    elsif ( is_aux_to_parent($a_node) ) {
        $a_node->set_edge_to_collapse(1);
        $a_node->set_is_auxiliary(1);
    }

    # Should collapse to node because the $parent is auxiliary?
    elsif ( is_parent_aux_to_me($a_node) ) {
        $a_node->set_edge_to_collapse(1);
        $parent->set_is_auxiliary(1);
    }

    # Some a-nodes don't belong to any of the t-nodes, but are auxiliary
    if ( is_aux_to_nothing($a_node) ) {
        $a_node->set_edge_to_collapse(0);
        $a_node->set_is_auxiliary(1);
    }
    return;
}

sub is_aux_to_parent {
    my ($a_node) = shift;
    return (
        ( $a_node->tag =~ /^Z/ and $a_node->afun !~ /Coord|Apos/ ) 
            || ( $a_node->afun  eq 'AuxV' )
            || ( $a_node->afun  eq 'AuxT' )
            || ( lc( $a_node->form ) eq 'jako' and $a_node->afun ne 'AuxC' )
            || ( $a_node->afun  eq 'AuxP' and $a_node->get_parent->afun eq 'AuxP' )
    );
}

sub is_parent_aux_to_me {
    my ($a_node) = shift;

    my $a_parent = $a_node->get_parent();
    return 0 if !$a_parent;

    # modal verbs
    return 1 if ( $a_node->afun ne 'Sb' && _is_infin($a_node) && _is_modal($a_parent) );

    # coordinated modal verbs    
    return 1 if ( $a_node->is_coap_root && _is_modal($a_parent) && any { _is_infin($_) && $_->afun ne 'Sb' } $a_node->get_children() );

    # state passive
    return 1 if ( $a_node->tag =~ /^Vs/ && $a_parent->lemma eq 'být' );

    # prepositions + particles, decayed parenthesis, emphasis
    return 1 if ( $a_parent->afun =~ /Aux[PC]/ && $a_node->afun !~ /^Aux[YZ]$/ );
    return 1 if ( lc( $a_parent->form ) eq "jako" && $a_parent->afun eq "AuxY" );

    return 0;
}

sub is_aux_to_nothing {
    my ($a_node) = shift;
    return ( ( !$a_node->get_children() ) && ( $a_node->afun eq 'AuxX' ) );
}

# Return 1 if the given node is an infinitive verb (in active or passive voice) 
sub _is_infin {
    my ($a_node) = shift;

    # active voice 'dělat'
    return 1 if ( $a_node->tag =~ /^Vf/ );

    # passive voice 'být dělán'
    return 1
        if (
        $a_node->tag =~ /^Vs/
        && any { $_->lemma eq 'být' && $_->tag =~ m/^Vf/ } $a_node->get_echildren( { or_topological => 1 } )
        );

    return 0;
}

# Return 1 if the given node is a modal verb
sub _is_modal {
    my ($a_node) = shift;

    # usual Czech modal verbs -- lemma is sufficient
    return 1 if ( $a_node->lemma =~ /^(muset|mít|chtít|hodlat|moci|dovést|umět|smět)(\_.*)?$/ );

    # (mostly) modal 'dát se'
    return 1 if ( $a_node->lemma eq 'dát' && grep { $_->form eq 'se' } $a_node->get_children() );
    return 0;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::CS::MarkEdgesToCollapse

=head1 DESCRIPTION

This prepares the a-tree for transformation into a t-tree by filling in the C<is_auxiliary> and C<edge_to_collapse>
attributes for auxiliary nodes that will not be present at the t-layer.

Before applying this block, afun values Aux[ACKPVX] and Coord must be filled.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2009-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
