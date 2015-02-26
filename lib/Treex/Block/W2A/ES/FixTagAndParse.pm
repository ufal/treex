package Treex::Block::W2A::ES::FixTagAndParse;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::Generation::ES;
my $generator = Treex::Tool::Lexicon::Generation::ES->new();
my $imperative_iset = Lingua::Interset::FeatureStructure->new({pos=> 'verb', verbform=>'fin', number=>'sing', mood=>'imp', person=>3});

sub process_anode {
    my ($self, $anode) = @_;
    my $lemma = $anode->lemma;
    
    # == Fix dependency structutre
    if ($anode->form eq '¿'){
        my $right_mark = $anode->get_siblings({last_only=>1});
        if (!$right_mark || $right_mark->form ne '?'){
            $right_mark = first {$_->form eq '?' && $_->follows($anode)} $anode->get_root->get_descendants({ordered=>1}) or return;
            if ($anode->follows($anode->get_parent)){
                $anode->set_parent($right_mark->get_parent()) if !$right_mark->is_descendant_of($anode);;
            } else {
                $right_mark->set_parent($anode->get_parent()) if !$anode->is_descendant_of($right_mark);
            }
        }
        # TODO if ($anode->follows($anode->get_parent) or $anode->get_siblings({preceding_only=>1})){ }
    }
    
    
    # == Fix lemma
    # There is no such lemma as "compruebe"
    if ($lemma eq 'compruebe'){
        $lemma = 'comprobar';
        if ($anode->is_noun){
            $anode->iset->add(pos=>'verb', gender=>'', nountype=>'', person=>'3', mood=>'imp');
        }
    };
    $lemma = 'parar' if $lemma eq 'paran';

    if ($lemma eq "mismos" || $lemma eq "mismas") {
	$lemma="mismo";
    }

    if ($lemma eq "al" && $anode->iset->pos eq "adp") {
	$lemma = "a";
	$anode->iset->add(definiteness=>'def', prontype=>'art');
    }

    if ($lemma eq "del" && $anode->iset->pos eq "adp") {
	$lemma = "de";
	$anode->iset->add(definiteness=>'def', prontype=>'art');
    }

    # "luces estén encendidas(lemma=encendidas -> encendido)"
    if ($anode->matches(pos=>'adj', verbform=>'part')){
        $lemma =~ s/s$// if $anode->is_plural;
        $lemma =~ s/a$// if $anode->is_feminine;
        $lemma .= 'o' if $lemma !~ /o$/;
    }
    $anode->set_lemma($lemma);
    
    # == Fix iset
    
    # lemma=hacer form=haga iset: ind sing 3 pres must be an error ($expected_form is "hace")
    #       comprobar  compruebe                                                       comprueba
    #       acceder    acceda                                                          accede
    # etc.
    #if ($anode->matches(mood=>'ind', number=>'sing', person=>'3', tense=>'pres')){
    if ($anode->is_verb){
        my $expected_form = $generator->best_form_of_lemma($lemma, $anode->iset);
        if ($expected_form ne lc $anode->form){
            my $imperative_form = $generator->best_form_of_lemma($lemma, $imperative_iset);
            # in our dataset imperative is more probable than subjunctive
            if ($imperative_form eq lc $anode->form){
                $anode->iset->set_hash($imperative_iset);
            }
        }           
    }
    
    # Subjunctive in the main clause is suspicious.
    # Very often the same form can be also an imperative, which is more probable.
    if ($anode->parent->is_root && $anode->matches(mood=>'sub', tense=>'pres', number=>'sing', person=>'3')){
        $anode->iset->set_mood('imp');
    }


    # Some subjects should be actually objects
    $self->fix_false_subject($anode);  
   
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
