package Treex::Block::A2T::EN::AddCorAct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
use Treex::Tool::Lexicon::EN;

sub process_tnode {
    my ( $self, $infin_verb ) = @_;

    # Process infinitives only
    return if !$infin_verb->is_infin;

    # Add the generated #Cor node
    my $cor = $infin_verb->create_child(
        {
            t_lemma  => '#Cor',
            functor  => 'ACT',
            formeme  => 'n:elided',
            nodetype => 'qcomplex',
        }
    );
    $cor->shift_before_node($infin_verb);

   
    # distinguish the control type (object vs. subject)
    return if $infin_verb->get_parent->is_root;
    my ($grandpa) = $infin_verb->get_eparents();
    my $antec_formeme = Treex::Tool::Lexicon::EN::is_object_control_verb( $grandpa->t_lemma || '_root' )
     ? 'n:obj' : 'n:subj';
     
    # Find the antecedent and fill the coreference link
    my $antec = first { $_->formeme eq $antec_formeme } $grandpa->get_echildren;
    if ($antec) {
        $cor->set_deref_attr( 'coref_gram.rf', [$antec] );
    }

    return 1;
}

1;
__END__

=head1 NAME

Treex::Block::A2T::EN::AddCorAct - add C<#Cor> nodes under infinitive

=head1 DESCRIPTION

New t-nodes with t_lemma C<#Cor> corresponding to unexpressed actors of infinitive
verbs are created. Grammatical coreference links are established to heuristically found
antecedents.

=head1 AUTHORS

Zdeněk Žabokrtský
Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.