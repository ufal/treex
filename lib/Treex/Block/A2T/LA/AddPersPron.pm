package Treex::Block::A2T::LA::AddPersPron;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %iset2gram = (
    # gender
    masc => 'anim', # Czech-specific grammateme mixing animateness and gender
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
);

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # Focus on clause heads (typically verbs),
    # which do not have any ACTor (or noun in nominative)
    return if !$t_node->is_clause_head;
    return if any {($_->functor||'') eq 'ACT' || ($_->formeme||'') eq 'n:1'} $t_node->get_echildren();

    # TODO: Do we want to do anything if the t_lemma does not end with 'r'?
    # If not, this 'return' would simplify the code below
    #return if $t_node->t_lemma !~ /r$/;

    # TODO we could also do
    #foreach my $anode ($t_node->get_anodes()){
    #    foreach my $cat (qw(person gender number)){
    #        my $value = $iset2gram{$anode->iset->get($cat)};
    #        next if !$value;
    #        $t_node->set_attr("gram/$cat", $value);
    #    }
    #}

    # Detect person, gender and number of the new ACT #PersPron
    my @anode_tags = map {$_->tag} $t_node->get_anodes();
    my ($person, $gender, $number);
    my $should_add = 1;
    #my ( $aux_gender, $aux_number );

    if (any {/^3..[JKLMNOPQ]...[47]/} @anode_tags){
        # at least one of the @anode_tags matches the regex
        $person = 1;
        #????? DON'T ADD A NEW NODE PersPron if t_lemma does not end with 'r'
        $should_add = 0 if $t_node->t_lemma !~ /r$/;
    }
    elsif ( any {/^3..[ABCDEGH]...[47]/} @anode_tags ) { # include 'ego', 'nos'
        $person = 1;
    }
    elsif ( any {/^3..[JKLMNOPQ]...[58]/} @anode_tags ) { # include 'tu', 'vos'
        $person = 2;
        #???? DON'T ADD A NEW NODE PersPron if t_lemma does not end with 'r'
        $should_add = 0 if $t_node->t_lemma !~ /r$/;
    }
    elsif ( any {/^3..[ABCDEGH]...[58]/} @anode_tags ) { # include 'tu', 'vos'
        $person = 2;
    }
    else {
        $person = 3;
    }

    # if ( any { ( $_ =~ /^3..[789]...[ABCDEGH]/ ) || ( ( $_ =~ /^3..[789]...[JKLMNOP]/ ) && $t_node->t_lemma =~ /r$/ ) } @anode_tags ) {
    #    $number = 'pl';
    #}
    if (any {/^3..[JKLMNOPQ]...[789]/} @anode_tags){
        # at least one of the @anode_tags matches the regex
        #????? DON'T ADD A NEW NODE PersPron if t_lemma does not end with 'r'
        $number = 'pl';
        $should_add = 0 if $t_node->t_lemma !~ /r$/;
    }
    elsif (any {/^3..[ABCDEGH]...[789]/} @anode_tags ){
        $number = 'pl';
    }
    # elsif ( any { ( $_ =~ /^3..[456]...[ABCDEGH]/ ) || ( ( $_ =~ /^3..[456]...[JKLMNOP]/ ) && $t_node->t_lemma =~ /r$/ ) } @anode_tags ) {
    #    $number = 'sg';
    #}
    elsif ( any { $_ =~ /^3..[JKLMNOPQ]...[456]/ } @anode_tags ) { # include 'tu', 'vos'
        $number = 'sg';
        #???? DON'T ADD A NEW NODE PersPron if t_lemma does not end with 'r'
        $should_add = 0 if $t_node->t_lemma !~ /r$/;
    }
    elsif ( any { $_ =~ /^3..[ABCDEGH]...[456]/ } @anode_tags ) { # include 'tu', 'vos'
        $number = 'sg';
    }

    return if !$should_add;

    # Add ACT/#PersPron node
    my $new_node = $t_node->create_child();
    $new_node->set_t_lemma('#PersPron');
    $new_node->set_functor('ACT');
    $new_node->set_formeme('drop');
    $new_node->set_nodetype('complex');
    $new_node->set_gram_sempos('n.pron.def.pers');
    $new_node->set_is_generated(1);
    $new_node->shift_before_node($t_node);
    $new_node->set_gram_person($person);
    $new_node->set_gram_gender($gender);
    $new_node->set_gram_number($number);
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

Latin nodes with t_lemma #PersPron corresponding to unexpressed ('prodropped') subjects of finite clauses
are added.

=head1 AUTHORS

Christophe Onambélé <christophe.onambele@unicatt.it>

Berta González Saavedra <Berta.GonzalezSaavedra@unicatt.it>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by The CIRCSE Research Centre, Università Cattolica del Sacro Cuore (Milan, Italy)

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
