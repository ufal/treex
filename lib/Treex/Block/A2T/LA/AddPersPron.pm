package Treex::Block::A2T::LA::AddPersPron;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %iset2gram = (
    # gender
    masc => 'anim', 
    fem => 'fem',
    neut => 'neut',
    # number
    sing => 'sg',
    plur => 'pl',
    dual => 'du',
    # person
    1 => 1,
    2 => 2,
    3 => 3,
    # politeness
    common => 'basic',
    polite => 'polite',
);

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # Detect person, gender and number of the new ACT #PersPron
    my @anode_tags = map {$_->tag} $t_node->get_anodes();
    my ($person, $gender, $number, $politeness);
    my $should_add = 1;
    #my ( $aux_gender, $aux_number );


    # Focus on clause heads (typically verbs, with tag 2 - participles - or 3 - verbal inflected forms - in first position),
    # which do not have any ACTor (or noun in nominative)
    return if ! any { /^[23]/ } @anode_tags;
    return if any {($_->functor||'') eq 'ACT' || ($_->formeme||'') eq 'n:1'} $t_node->get_echildren();

    # TODO: Do we want to do anything if the t_lemma does not end with 'r'?
    # If not, this 'return' would simplify the code below
    #return if $t_node->t_lemma !~ /r$/;

    # If we want to get rid of a list of specific lemmas... 
    #return if $t_node->t_lemma =~ /appare/;

    # Exclude members of coordinated structures. is_member=1
    return if $t_node->is_member;

    # Exclude passive forms of not deponent verbs
    if (any { /^[23]..[JKLMNOPQ]/ } @anode_tags) {
        $should_add = 0 if $t_node->t_lemma !~ /r$/;
    }

    # Exclude adverbial forms (like "convenienter")
    if (any { /^[23].....G/ } @anode_tags) {
        $should_add = 0;
    }

    # Exclude infinitives (H: active infinitives; Q: passive infinitives) and exclude gerunds (E: active gerunds; N: passive gerunds)
    if (any { /^[23]..[HQEN]/ } @anode_tags) {
        $should_add = 0;
    }


    # TODO we could also do
    #foreach my $anode ($t_node->get_anodes()){
    #    foreach my $cat (qw(person gender number)){
    #        my $value = $iset2gram{$anode->iset->get($cat)};
    #        next if !$value;
    #        $t_node->set_attr("gram/$cat", $value);
    #    }
    #}


    # If a passive form; 1 person; sing,pl
    if (any { /^3..[JKL]...[47]/ } @anode_tags) {
        $person = 1;
        $politeness = 'basic';
        $should_add = 0 if $t_node->t_lemma !~ /r$/;
    }

    # active; 1 pers; sing,plur
    elsif ( any { /^3..[ABC]...[47]/ } @anode_tags ) { # include 'ego', 'nos'
        $politeness = 'basic';
        $person = 1;
    }
    # passive 2 pers, sing plur
    elsif ( any { /^3..[JKL]...[58]/ } @anode_tags ) { # include 'tu', 'vos'
        $person = 2;
        $politeness = 'basic';
        $should_add = 0 if $t_node->t_lemma !~ /r$/;
    }
    # passive; 2 pers; sing,plur
    elsif ( any { /^3..[ABC]...[58]/ } @anode_tags ) { # include 'tu', 'vos'
        $politeness = 'basic';
        $person = 2;
    }
    else {
        $politeness = 'basic';
        $person = 3;
    }
    
    # passive plural
    if ( any { /^3..[JKL]...[789]/ } @anode_tags ) {
        $number = 'pl';
        $politeness = 'basic';
        $should_add = 0 if $t_node->t_lemma !~ /r$/;
    }
    # active plural
    elsif ( any { /^3..[ABC]...[789]/ } @anode_tags ) {
        $politeness = 'basic';
        $number = 'pl';
    }
   
    # passive plural
    elsif ( any { /^3..[JKL]...[456]/ } @anode_tags ) { # include 'tu', 'vos'
        $number = 'sg';
        $politeness = 'basic';
        $should_add = 0 if $t_node->t_lemma !~ /r$/;
    }
    # active singular
    elsif ( any { /^3..[ABC]...[456]/ } @anode_tags ) { # include 'tu', 'vos'
        $politeness = 'basic';
        $number = 'sg';
    }
    
    # PARTICIPLES (D), SUPINE (G) with SINGULAR CASE ([A-H]), and MASCULINE GENDER (1) --> active verbs
     if ( any { /^2..[DG]..[A-H]1/  } @anode_tags ) {
        $number = 'sg';
        $gender = 'anim';
        $person = '3';
        $politeness = 'basic';
    }
    
    elsif ( any { /^2..[DG]..[A-H]2/ } @anode_tags ) {
        $number = 'sg';
        $gender = 'fem';
        $person = '3';
        $politeness = 'basic';
    }
    
    elsif ( any { /^2..[DG]..[A-H]3/ } @anode_tags ) {
        $number = 'sg';
        $gender = 'neut';
        $person = '3';
        $politeness = 'basic';
    }
    
    elsif ( any { /^2..[DG]..[JKLMNO]1/  } @anode_tags ) {
        $number = 'pl';
        $gender = 'anim';
        $person = '3';
        $politeness = 'basic';
    }
    
    elsif ( any { /^2..[DG]..[JKLMNO]2/ } @anode_tags ) {
        $number = 'pl';
        $gender = 'fem';
        $person = '3';
        $politeness = 'basic';
    }
    
    elsif ( any { /^2..[DG]..[JKLMNO]3/ } @anode_tags ) {
        $number = 'pl';
        $gender = 'neut';
        $person = '3';
        $politeness = 'basic';
    }
    
    # PARTICIPLES (M), GERUNDIVES (O), and SUPINE (P) with deponent verbs
    elsif ( any { /^2..[MOP]..[A-H]1/ } @anode_tags ) {
        $number = 'sg';
        $gender = 'anim';
        $person = '3';
        $politeness = 'basic';
    }
    
    elsif ( any { /^2..[MOP]..[A-H]2/ } @anode_tags ) {
        $number = 'sg';
        $gender = 'fem';
        $person = '3';
        $politeness = 'basic';
    }
    
    elsif ( any { /^2..[MOP]..[A-H]3/ } @anode_tags ) {
        $number = 'sg';
        $gender = 'neut';
        $person = '3';
        $politeness = 'basic';
    }
    
    elsif ( any { /^2..[MOP]..[JKLMNO]1/ } @anode_tags ) {
        $number = 'pl';
        $gender = 'anim';
        $person = '3';
        $politeness = 'basic';
    }
    
    elsif ( any { /^2..[MOP]..[JKLMNO]2/ } @anode_tags ) {
        $number = 'pl';
        $gender = 'fem';
        $person = '3';
        $politeness = 'basic';
    }
    
    elsif ( any { /^2..[MOP]..[JKLMNO]3/ } @anode_tags ) {
        $number = 'pl';
        $gender = 'neut';
        $person = '3';
        $politeness = 'basic';
    }
    
    return if !$should_add;

    # Add ACT/#PersPron node
    my $new_node = $t_node->create_child();
    $new_node->set_t_lemma('#PersPron');
    $new_node->set_functor('ACT');
    # $new_node->set_formeme('drop');
    $new_node->set_nodetype('complex');
    $new_node->set_gram_sempos('n.pron.def.pers');
    $new_node->set_is_generated(1);
    $new_node->shift_before_node($t_node);
    $new_node->set_gram_person($person);
    $new_node->set_gram_gender($gender);
    $new_node->set_gram_number($number);
    $new_node->set_gram_politeness($politeness); 
    #$new_node->wild->{'aux_gram/number'} = $aux_number if (defined $aux_number);
    #$new_node->wild->{'aux_gram/gender'} = $aux_gender if (defined $aux_gender);

    return;
}


1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::LA::AddPersPron

=head1 DESCRIPTION

Latin nodes with t_lemma #PersPron corresponding to unexpressed subjects of finite clauses are added.

=head1 AUTHORS

Christophe Onambélé <christophe.onambele@unicatt.it>

Berta González Saavedra <Berta.GonzalezSaavedra@unicatt.it>

Martin Popel <popel@ufal.mff.cuni.cz>

Marco Passarotti <marco.passarotti@unicatt.it>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by The CIRCSE Research Centre, Università Cattolica del Sacro Cuore (Milan, Italy)

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
