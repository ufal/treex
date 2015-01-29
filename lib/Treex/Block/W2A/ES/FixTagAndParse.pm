package Treex::Block::W2A::ES::FixTagAndParse;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ($self, $anode) = @_;
    my $lemma = $anode->lemma;
    
    # == Fix lemma
    # There is no such lemma as "compruebe"
    if ($lemma eq 'compruebe'){
        $lemma = 'comprobar';
        if ($anode->is_noun){
            $anode->iset->add(pos=>'verb', gender=>'', nountype=>'', person=>'3', mood=>'imp');
        }
    };
    $lemma = 'parar' if $lemma eq 'paran';

    # "luces estén encendidas(lemma=encendidas -> encendido)"
    if ($anode->matches(pos=>'adj', verbform=>'part')){
        $lemma =~ s/s$// if $anode->is_plural;
        $lemma =~ s/a$// if $anode->is_feminine;
        $lemma .= 'o' if $lemma !~ /o$/;
    }
    $anode->set_lemma($lemma);
    
    # == Fix iset
    
    if ($lemma eq 'comprobar' && lc $anode->form eq 'compruebe'){        
        # 3rd person singular indicative present would be "comprueba", this must be an error
        if ($anode->matches(mood=>'ind', number=>'sing', person=>'3', tense=>'pres')){
            $anode->iset->set_mood('imp');
        }
    }
    
    # Subjunctive in the main clause is suspicious.
    # Very often the same form can be also an imperative, which is more probable.
    if ($anode->parent->is_root && $anode->matches(mood=>'sub', tense=>'pres', number=>'sing', person=>'3')){
        $anode->iset->set_mood('imp');
    }


    # Some subjects should be actually objects
    $self->fix_false_subject($anode);  
    
    #=== The following are issues of HamleDT::ES::Harmonize rather than W2A::ES::TagAndParse
    if ($lemma eq 'uno' && $anode->conll_deprel eq 'spec'){
        $anode->iset->set_prontype('art');
    }
    if ($anode->is_article){
        $anode->set_afun('AuxA');
        $anode->iset->set_definiteness($lemma eq 'el' ? 'def' : 'ind');
    }
    
    $anode->set_tag(join ' ', $anode->get_iset_values);
    return;
}

sub fix_false_subject {
    my ($self, $anode) = @_;
    return if !$anode->is_verb;
    my @children = $anode->get_echildren({or_topological=>1});
    my $subject_child = first {$_->afun eq 'Sb'} @children;
    return if !$subject_child;
    
    my $is_first_person_verb = $anode->iset->person eq '1' ? 1 : 0;
    $is_first_person_verb = 1 if $anode->is_infinitive && any {$_->iset->person eq '1' && $_->afun eq 'AuxV'} @children;
    
    if ($is_first_person_verb && $subject_child->iset->person ne '1'){
        $subject_child->set_afun('Obj');
    }
    return;
}

1;

__END__

=encoding utf8

=head1 NAME

Treex::Block::W2A::ES::FixTagAndParse - fix IXA-Pipes errors

=head1 DESCRIPTION


=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
