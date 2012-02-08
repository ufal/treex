package Treex::Block::A2T::CS::MarkReflexivePassiveGen;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';


sub process_tnode {

    my ( $self, $tnode ) = @_;

    # Mark AuxR reflexive passive particles as ACT/#Gen
    if ($tnode->is_clause_head &&
         ( my $auxr = first { my $a = $_->get_lex_anode(); $a and $a->afun eq 'AuxR' }
         $tnode->get_echildren( { or_topological => 1 } ) ) ){

        $auxr->set_functor('ACT');
        $auxr->set_formeme('x');
        $auxr->set_t_lemma('#Gen');
        $auxr->set_nodetype('qcomplex');
        $auxr->set_is_generated(1);
        $auxr->set_attr('gram', undef);
    }    
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::CS::MarkReflexivePassiveGen

=head1 DESCRIPTION

T-nodes corresponding to Czech reflexive passive particles ('se') are changed to generated #Gen qcomplex
nodes with the ACT functor.

This prevents creating ACT #PersPron-s in L<Treex::Block::A2T::CS::AddPersPron> and reflexive pronoun
coreferences in L<Treex::Block::A2T::CS::MarkReflpronCoref> 

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
