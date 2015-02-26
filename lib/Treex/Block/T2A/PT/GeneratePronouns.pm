package Treex::Block::T2A::PT::GeneratePronouns;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# TODO: using the regularities, both pronoun tables can be written in a more concise way
my %PRON_FORM = (
    "POSS" => {  # dimensions:   person of the possessor, gender of the possessed object, number of the possessed object, number of the possessor

    '1 masc sing sing' => 'meu', 
    '1 fem sing sing' => 'minha', 
    '1 masc plur sing' => 'meus', 
    '1 fem plur sing' => 'minhas', 

    '1 masc sing plur' => 'nosso', 
    '1 fem sing plur' => 'nossa', 
    '1 masc plur plur' => 'nossos', 
    '1 fem plur plur' => 'nossas', 

    '2 masc sing sing' => 'teu', 
    '2 fem sing sing' => 'tua', 
    '2 masc plur sing' => 'teus', 
    '2 fem plur sing' => 'tuas', 

    '2 masc sing plur' => 'vosso', 
    '2 fem sing plur' => 'vossa', 
    '2 masc plur plur' => 'vossos', 
    '2 fem plur plur' => 'vossas', 

    '3 masc sing sing' => 'seu', 
    '3 fem sing sing' => 'sua', 
    '3 masc plur sing' => 'seus', 
    '3 fem plur sing' => 'suas', 

    '3 masc sing plur' => 'seu', 
    '3 fem sing plur' => 'sua', 
    '3 masc plur plur' => 'seus', 
    '3 fem plur plur' => 'suas', 
   },

    "NOM" => { # dimensions: person, gender, number
    '1 masc sing' => 'eu', 
    '1 fem sing ' => 'eu', 
    '1 masc plur' => 'nós', 
    '1 fem plur' => 'nós', 
    
    '2 masc sing' => 'tu', 
    '2 fem sing' => 'tu', 
    '2 masc plur' => 'vós', # vóce (BP)- not needed for generation, but might be important for analysis of a corpus
    '2 fem plur' => 'vós',  # the same

    
    '3 masc sing' => 'ele', 
    '3 fem sing' => 'ela', 
    '3 masc plur' => 'eles', 
    '3 fem plur' => 'elas', 
},

"OBL" => {
    '1 masc sing' => 'mim', #Possible variation: comigo
    '1 fem sing' => 'mim',  #Possible variation: comigo
    '1 masc plur' => 'nós', #Possible variation: connosco
    '1 fem plur' => 'nós',  #Possible variation: connosco

    '2 masc sing' => 'ti',  #Possible variation: contigo
    '2 fem sing' => 'ti',   #Possible variation: contigo
    '2 masc plur' => 'vós', #Possible variation: convosco
    '2 fem plur' => 'vós',  #Possible variation: convosco

    '3 masc sing' => 'ele',
    '3 fem sing' => 'ela',
    '3 masc plur' => 'eles',
    '3 fem plur' => 'elas',

    },


"ACC" => {

    '1 masc sing' => '-me',
    '1 fem sing' => '-me',
    '1 masc plur' => '-nos',
    '1 fem plur' => '-nos',

    '2 masc sing' => '-te',
    '2 fem sing' => '-te',
    '2 masc plur' => '-vos',
    '2 fem plur' => '-vos',

    '3 masc sing' => '-o',
    '3 fem sing' => '-a',
    '3 masc plur' => '-os',
    '3 fem plur' => '-as',

    },

"DAT" => {  # TODO: dative not recognized yet

    '1 masc sing' => '-me',
    '1 fem sing' => '-me',
    '1 masc plur' => '-nos',
    '1 fem plur' => '-nos',

    '2 masc sing' => '-te',
    '2 fem sing' => '-te',
    '2 masc plur' => '-vos',
    '2 fem plur' => '-vos',

    '3 masc sing' => '-lhe',
    '3 fem sing' => '-lhe',
    '3 masc plur' => '-lhes',
    '3 fem plur' => '-lhes',
    },
);

sub process_tnode {

    my ( $self, $t_node ) = @_;

    # select only negated verbs
    return if $t_node->t_lemma ne "#PersPron";
    my $a_node = $t_node->get_lex_anode() or return;

    my $type;
    my $key;
    my $iset = $a_node->iset;

    if ($t_node->formeme =~ /poss/) {  # possessive pronouns
        $type = "POSS";
        $key = join " ", ($iset->person, $iset->gender||"masc", $iset->number||"sing", $iset->possnumber);
    }

    elsif ($t_node->formeme =~ /subj/) {
        $type = "NOM";
        $key = join " ", ($iset->person, $iset->gender, $iset->number);

    }

    elsif ($t_node->formeme =~ /obj/ ) { # dative or accusative, we cannot recognize now, so everything goes to acc
        $type = "ACC";
        $key = join " ", ($iset->person, $iset->gender, $iset->number); # TODO CHECK
    }

    elsif ($t_node->formeme =~ /\+/) {  # oblique case
        $type = "OBL";
        $key = join " ", ($iset->person, $iset->gender, $iset->number); # TODO CHECK
    }

    else {
        log_warn "THIS should never happen, unrecognized pronoun formeme".$t_node->formeme."\n";
    }

    my $form = $PRON_FORM{$type}{$key};
    if (not defined $form) {    
        log_warn "ERROR: No pronoun form of type $type for morphological categories equal to $key\t".$t_node->get_address."\n";  
    }
    else  {
        $a_node->set_form($form);
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::PT::GeneratePronouns

=head1 DESCRIPTION

Generates portuguese pronouns using the formeme and the Interset person, gender and number

=head1 AUTHORS

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

João A. Rodrigues <jrodrigues@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by NLX Group, Universidade de Lisboa

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


