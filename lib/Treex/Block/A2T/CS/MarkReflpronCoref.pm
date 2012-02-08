package Treex::Block::A2T::CS::MarkReflpronCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    
    my ( $self, $t_node ) = @_;

    # Select only such reflexive pronouns that are full t-nodes (not reflexive passives (qcomplex) or auxiliaries (no t-nodes))
    if ( $t_node->get_lex_anode && $t_node->nodetype eq 'complex' && $t_node->get_lex_anode->tag =~ /^.[678]/ ) {
    
        # Attempt to find the clause head
        my $clause_head = $t_node;    
        while ( $clause_head->get_parent and not $clause_head->is_clause_head ) {
            $clause_head = $clause_head->get_parent;
        }
    
        # We found a clause head (since it did not run all the way up to the root)
        if ( !$clause_head->is_root ) {

            my ($antec) = grep { ( $_->formeme || "" ) =~ m/^(n:1|drop)$/ } $clause_head->get_echildren( { or_topological => 1 } );
            
            # Mark the coreference (skip AuxR 'ACT/PersPron' nodes which have the 'drop')
            if ($antec && $antec != $t_node) {
                $t_node->set_deref_attr( 'coref_gram.rf', [$antec] );
            }
        }
    }
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::CS::MarkReflpronCoref

=head1 DESCRIPTION

Coreference link between a t-node corresponding to reflexive pronoun (inc. reflexive possesives)
and its antecedent (in the sense of grammatical coreference) is detected in Czech t-trees
and stored in the C<coref_gram.rf> attribute.

This block requires formemes and reconstructed pro-dropped subjects and reflexive passive #Gen subjects.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
