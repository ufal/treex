package Treex::Block::A2T::EN::AddCorAct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
use Treex::Tool::Lexicon::EN;

sub is_present_participle {
    my ($verb) = @_;
    my $averb = $verb->get_lex_anode;
    return (defined $averb && $averb->is_verb && $averb->is_present && $averb->is_participle && (($verb->gram_verbmod // "nil") eq "nil"));
}

sub is_past_participle {
    my ($verb) = @_;
    my $averb = $verb->get_lex_anode;
    return (defined $averb && $averb->is_verb && $averb->is_past && $averb->is_participle && (($verb->gram_verbmod // "nil") eq "nil"));
}

sub process_tnode {
    my ( $self, $verb ) = @_;

    my $functor;
    # Process infinitives only
    if ($verb->is_infin) {
        $functor = "ACT";
    }
    elsif (is_present_participle($verb)) {
        $functor = "ACT";
    }
    elsif (is_past_participle($verb)) {
        $functor = "PAT";
    }
    else {
        return;
    }
        
    # Some non-finite constructions may have the key argument expressed on surface -> let's skip them
    return if any {$_->functor eq $functor} $verb->get_children();

    # Add the generated #Cor node
    my $cor = $verb->create_child(
        {
            is_generated => 1,
            t_lemma      => '#Cor',
            functor      => $functor,
            formeme      => 'n:elided',
            nodetype     => 'qcomplex',
        }
    );
    $cor->shift_before_node($verb);

   
    # distinguish the control type (object vs. subject)
    return if $verb->get_parent->is_root;
    my ($grandpa) = $verb->get_eparents();
    my $antec_formeme;
    if ($verb->is_infin) {
        $antec_formeme = Treex::Tool::Lexicon::EN::is_object_control_verb( $grandpa->t_lemma || '_root' )
            ? 'n:obj' : 'n:subj';
    }
    # TODO: rule-based antecedent selection could be implemented in a more clever way
    elsif (is_present_participle($verb)) {
        $antec_formeme = 'n:subj';
    }
    elsif (is_past_participle($verb)) {
        $antec_formeme = 'n:obj';
    }
     
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
