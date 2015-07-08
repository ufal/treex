package Treex::Block::A2T::LA::SetFunctors;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# Fallback tables
my %FUNCTOR_FOR_AFUN = (
    Apos  => 'APPS',
    Atr   => 'RSTR',
    Obj   => 'PAT',
    Sb    => 'ACT',
    Pred  => 'PRED',
    Atv   => 'COMPL',
    AtvV  => 'COMPL',
    OComp => 'EFF',
    Adv   => 'MANN',
);

my %FUNCTOR_FOR_LEMMA = (
    'non latina vox' => 'FPHR',
    meuus       => 'APP',
    tuus        => 'APP',
    suus        => 'APP',
    noster      => 'APP',
    vester      => 'APP',
    nihilominus => 'CNCS',
    hinc        => 'TFRWH',
    inde        => 'TFRWH',
    interdum    => 'THO',
    simul       => 'TPAR',
    quomodo     => 'MANN',
    sic         => 'MANN',
    vix         => 'MANN',
);

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # Skip coap nodes with already assigned functors
    return if $t_node->functor;

    # Set functor, '???' marks unknown values
    $t_node->set_functor( $self->guess_functor($t_node) || '???' );
    return;
}

sub guess_functor {
    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode() or return;
    my ( $lemma, $afun, $tag, $form ) = $a_node->get_attrs(qw(lemma afun tag form));
    my ($t_eparent) = $t_node->get_eparents();
    my $a_eparent = $t_eparent->get_lex_anode || $a_node->get_root;
    my ( $p_lemma, $p_afun, $p_tag, $p_form ) = ( '', '', '', '' );
    if ( !$a_eparent->is_root ) {
        ( $p_lemma, $p_afun, $p_tag, $p_form ) = $a_eparent->get_attrs(qw(lemma afun tag form));
    }
    my $p_lemma_or = ($p_lemma =~ /or$/); # Is parent a deponent verb (ie, with lemma ending in -or)?
    my %is_lemma_of_a_child = map {$_->lemma => 1} $a_node->get_echildren();

    # Subjects
    # TODO: $FUNCTOR_FOR_AFUN{Sb}='ACT', so we can delete all ACT rules below and keep just the PAT rules
    if ( $afun eq 'Sb' ) {       
        return 'ACT' if $p_tag =~ /^3..[ABCDH]/; # Sb depending on active verbs
        return 'PAT' if $p_tag =~ /^3..[JKLMQ]/ && !$p_lemma_or; # Sb depending on passive verbs - not deponent
        if ($tag =~ /^......[FO]/){
            # ablative absolute: ACT to Sb of present participle (mediantibus rebus)
            return 'ACT' if $p_tag =~ /^2..D..[FO]/;
            # ablative absolute: PAT to Sb of past participle (praesupposita materia)
            return 'PAT' if $p_tag =~ /^2..M..[FO]/ && !$p_lemma_or;
        } else {
            # The subject of non-deponent composite verbs (formata est) is PAT. The composite verbal form has passive meaning 
            return 'PAT' if $p_tag =~ /^2..M/ && !$p_lemma_or;
            # The subject of deponent composite verbs (nata est) is ACT 
            return 'ACT' if $p_tag =~ /^2..M/ && $p_lemma_or;
        }
        # Sb depending on deponent verbs
        return 'ACT' if $p_lemma_or;
    }

    if ($afun eq 'Adv'){
        return 'MEANS' if $p_lemma eq 'per';        
        return 'CAUS' if $form eq 'hoc' && $p_form eq 'ex' && $is_lemma_of_a_child{quod};
        return 'CAUS' if $p_lemma eq 'quia';
        return 'CNCS' if $p_lemma eq 'quamvis';
        return 'COND' if $p_lemma eq 'si';
        return 'CAUS' if $p_lemma eq 'quod' && $a_eparent->get_parent->lemma eq 'secundum';
    }

    return 'CAUS' if $form eq 'ratione';
    return 'COMPL' if $afun eq 'Atv' || $afun eq 'AtvV';
    return 'MANN' if $form =~ /iter$/;
    return 'MANN' if $tag =~ /^......G/; # "casus adverbialis" 

    if ($afun eq 'AuxY') {
        return 'PREC' if any {$lemma eq $_} (qw(ergo nam enim unde igitur ideo tamen idcirco ideo propterea praeterea quidem tunc deinde));
        return 'PREC' if $form eq 'vero';
    }

    return 'MOD' if any {$form eq $_} (qw(forte forsitan));
    return 'INTF' if any {$lemma eq $_} (qw(ecce iam));
    return 'ATT' if any {$form eq $_} (qw(potior vere));
    return 'PAT' if $afun eq 'Pnom' && any {$p_lemma eq $_} (qw(sum maneo remaneo appareo redeo resto subsisto existo));
    return 'RHEM' if $afun eq 'AuxZ' && any {$lemma eq $_} (qw(etiam non et item));
    return 'EXT' if any {$lemma eq $_} (qw(fere omnino prope prorsus quanto quasi tam tantum));
    return 'EXT' if $afun eq 'AuxZ' && $form eq 'multo';
    return 'TWHEN' if any{$lemma eq $_} (qw(statim subito));

    # EFF <= afun Pnom depending on a verbs with three arguments, one of which is tagged OComp in the active voice
    return 'EFF' if $afun eq 'Pnom' && any {$p_lemma eq $_} 
        (qw(accipio apprehendo arbitror computo considero constituo credo creo
        definio denomino dico efficio facio habeo intelligo invenio nomino
        ostendo pono praedico prohibeo propono rapraesento reddo refero resumo
        significo teneo voco));
    
    # Modal+Infinitives
    # Infinitives ([HQ]) depending on modal verbs get the functor according to the afun of their parent (i.e. the modal verb).
    # TODO The best would be to automatically assign to the infinitives the same functor of their parent: but how?
    # TODO Managing coordination (possum facere et dicere)
    # Although they are tagged with afun Obj, they do not receive functor "PAT" (as usually).
    # This rule is needed in order to assign the correct functor to the infinitive,
    # once the modal verb is collapsed and the infinitive becomes the head.
    # See the rule on modal verbs in the A2T::LA::MarkEdgesToCollapse block.
    if ($afun eq 'Obj' && $tag =~ /^3..[HQ]/ && any {$p_lemma eq $_} qw(possum debeo volo nolo malo soleo incipio desino intendo)) {
        return 'PRED' if  $p_afun eq 'Pred';
        return 'PAT' if $p_afun eq 'Obj';
        return 'RSTR' if $p_afun eq 'Atr';
        return 'ACT' if $p_afun eq 'Sb';
        return 'RSTR' if $p_afun eq 'Adv' || $p_afun eq 'ExD';
    }
   
    if ($afun eq 'Coord') {
         return 'CONJ'  if any {$lemma eq $_} (qw(et nec neque));
         return 'DISJ'  if any {$lemma eq $_} (qw(vel aut sive));
         return 'ADVS'  if any {$lemma eq $_} (qw(sed autem));
    }
    
    # Fallbacks
    return $FUNCTOR_FOR_LEMMA{$lemma} || $FUNCTOR_FOR_AFUN{$afun} || 'RSTR';
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::LA::SetFunctors - guess Latin functor using hand-written rules

=head1 DESCRIPTION 

Coordination and apposition functors must be filled before using this block
(it uses effective parents and effective children).

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

David Mareček

Marco Passarotti 

=head1 COPYRIGHT AND LICENSE

Copyright © 2012,2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
