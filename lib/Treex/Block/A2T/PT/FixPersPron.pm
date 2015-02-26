package Treex::Block::A2T::PT::FixPersPron;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %FORM2GRAMMATEMES = (

    'meu' => '1 sing',
    'minha' => '1 sing' ,
    'meus' => '1 sing',
    'minhas' => '1 sing' ,
    'nosso' => '1 plur',
    'nossa' => '1 plur' ,
    'nossos' =>'1 plur',
    'nossas' => '1 plur' ,
    'teu' => '2 sing',
    'tua' => '2 sing' ,
    'teus' => '2 sing',
    'tuas' => '2 sing' ,
    'vosso' => '2 plur',
    'vossa' => '2 plur' ,
    'vossos' =>'2 plur',
    'vossas' => '2 plur' ,
    'seu' => '3 sing',
    'sua' => '3 sing' ,
    'seus' => '3 plur',
    'suas' => '3 plur' ,

    'eu' => '1 sing',
    'nós' => '1 plur',
    'tu' => '2 sing',
    'vós' => '2 plur',
    'ele' => '3 masc sing' ,
    'ela' => '3 fem sing',
    'eles' => '3 masc plur' ,
    'elas' => '3 fem plur',

    'mim' =>'1 sing', #Possible variation: comigo
    'nós' =>'1 plur', #Possible variation: connosco

    'ti'  =>'2 sing',  #Possible variation: contigo
    'vós' =>'2 plur', #Possible variation: convosco

    '-me' =>'1 sing', 
    '-nos' =>'1 plur', 
    '-te' =>'2 sing', 
    '-vos' =>'2 plur', 

    '-o' => '3 masc sing',
    '-a' => '3 fem sing', 
    '-os' => '3 masc plur',
    '-as' => '3 fem plur', 

    '-lhe' => '3 sing',
    '-lhes' => '3 plur',

);


sub process_tnode {
    my ( $self => $t_node ) = @_;
    my $anode = $t_node->get_lex_anode();


    if ($t_node->t_lemma eq "#PersPron" and $t_node->is_generated and $t_node->gram_person eq "3" and $t_node->get_parent->t_lemma ne "haver") {
        $t_node->set_gram_politeness("polite");
        $t_node->set_gram_person(2);
    }


    elsif ($anode and ($anode->iset->prontype || "") eq "prs") {
        $t_node->set_t_lemma("#PersPron");

        my $stringified_grams = $FORM2GRAMMATEMES{lc($anode->form)};

        if ($stringified_grams) {

        	if ($stringified_grams =~ /(\d)/) {
        		$t_node->set_gram_person($1);
        	}
        	else {
        		$t_node->set_gram_person(3);
        	}

        	if ($stringified_grams =~ /plur/) {
        		$t_node->set_gram_number("pl");
        	}
        	else {
        		$t_node->set_gram_number("sg");
        	}

        	if ($stringified_grams =~ /fem/) {
        		$t_node->set_gram_gender("fem");
        	}
        	else {
        		$t_node->set_gram_gender("anim"); # actually all masculines, not only animate ones
        	}


            # the following 3rd person pronouns are rather used for polite 2nd person
            if ($anode->form =~ /^(-o|-a|seu|sua|seus|suas|-lhe|-lhes)$/i ) {
                $t_node->set_gram_politeness("polite");
                $t_node->set_gram_person(2);
            }

        }
        else {
        	log_warn "Unrecognized form of a personal pronoun: ".$anode->form;
        }

    }

    #If the modal verbs were colapsed...
    #if ($t_node->t_lemma eq "#PersPron" and $t_node->is_generated) {
    #
    #    print STDERR "FixPersPron perspron...\n";
    #
    #    #Se o pai teve filhos como verbos modais que colapsaram
    #    my $t_parent = $t_node->get_parent;
    #
    #    if($t_parent and grep {$_->lemma =~ /(poder|dever|querer)/} $t_parent->get_aux_anodes ){
    #
    #        $t_node->set_gram_politeness("polite");
    #        $t_node->set_gram_person(2);
    # 
    #    }
    #
    #}

    return 1;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::PT::FixPersPron

=head1 DESCRIPTION

Fix #PersPron grammatemes, extracting person, number and gender from node form.

=head1 AUTHOR

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

Copyright © 2014 by NLX Group, Universidade de Lisboa

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.