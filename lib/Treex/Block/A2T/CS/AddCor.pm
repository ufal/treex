package Treex::Block::A2T::CS::AddCor;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $verb_list_ACT = 'bavit|bránit_se|bát_se|být|chodit|chtít|chystat_se|cítit_potřeba|cítit_se|dařit_se|dojít|dokázat|dopřát_si|dostat|dostat_doporučení|dostat_rozkaz|dostat_úkol|dostávat_příležitost|dovolit_si|dovolovat_si|dovést|dát|hrozit|jet|jevit_se|jezdit|jít|klást|koukat|moci|mínit|mít|mít_chuť|mít_cíl|mít_důvod|mít_mechanismus|mít_motivace|mít_možnost|mít_naděje|mít_obava|mít_odvaha|mít_oprávnění|mít_potíž|mít_potěšení|mít_potřeba|mít_povinnost|mít_povolení|mít_pravomoc|mít_problém|mít_právo|mít_příležitost|mít_schopnost|mít_snaha|mít_síla|mít_tendence|mít_touha|mít_zájem|mít_úkol|mít_čas|mít_čest|mít_šance|nabízet_se_možnost|namáhat_se|napadnout|naskytnout_se_možnost|naskýtat_se_možnost|naučit_se|nechávat|náležet_právo|obtěžovat_se|obávat_se|odcházet|odejít|odmítat|odmítnout|odnaučit_se|odvažovat_se|odvážit_se|opomenout|ostýchat_se|plánovat|pociťovat_potřeba|podařit_se|pokoušet_se|pokusit_se|potřebovat|povést_se|projevit_nezájem|projevit_přání|projevit_zájem|přestat|přestávat|přicházet|přijet|přijít|přijít_možnost|přijíždět|přislíbit|přát_si|příslušet|příslušet_oprávnění|rozhodnout|rozhodnout_se|rozmyslit_si|rozpakovat_se|sbírat_odvaha|slibovat|slíbit|snažit_se|stačit|stihnout|stydět_se|svést|toužit|troufat_si|troufnout_si|ukazovat_se|ukázat_se|umět|unikat|usilovat|uvažovat|uvolit_se|uznat|učinit_pokus|učit_se|vydržet|vyhýbat_se|vyjádřit_ochota|vyjádřit_odhodlání|vyjádřit_připravenost|vyjádřit_přání|vyjádřit_vůle|vytknout|vyvinout_snaha|váhat|vědět|zajít|zamýšlet|zanikat_povinnost|zapomenout|zapomínat|zasloužit|zasloužit_si|zatoužit|zavázat_se|začínat|začít|zdráhat_se|zdát_se|zkoušet|zkusit|zkusit_si|ztratit_chuť|ztratit_možnost|zvyknout_si|získat_možnost|zůstat|zůstávat';
my $verb_list_PAT = 'nechat|spatřit|uvidět|vidět';
my $verb_list_ADDR = 'bránit|donutit|dopomoci|doporučit|doporučovat|dovolit|dovolovat|dát_možnost|dát_právo|dát_příležitost|dávat|dávat_možnost|dávat_naděje|dávat_právo|dávat_šance|napomoci|naučit|navrhnout|navrhovat|nařídit|nutit|opravňovat|oprávnit|otevírat_možnost|otevřít_možnost|podávat_návod|pomoci|pomáhat|poskytnout_možnost|povolit|povolovat|pověřit|pověřovat|přesvědčit|přikazovat|přikázat|přimět|přinutit|radit|ukládat|ukládat_povinnost|uložit|umožnit|umožňovat|určit|učit|velet|vydat_rozkaz|vypomoci|zabraňovat|zabránit|zakazovat|zakázat|zapovídat|zavazovat|zavázat|znemožnit|znemožňovat';
my $verb_list_ORIG = 'požadovat|vyžadovat';
my $verb_list_BEN = 'znamenat';

sub is_infinitive {
    my ($t_node) = @_;
    return (  $t_node->get_lex_anode and $t_node->get_lex_anode->tag =~ /^Vf/ 
        and not $t_node->is_clause_head
    ) ? 1 : 0;
}

sub is_refl_pass {
    my ($t_node) = @_;
    foreach my $anode ( $t_node->get_anodes ) {
        return 1 if ( grep { $_->afun eq "AuxR" and $_->form eq "se" } $anode->children );
    }
    return 0;
}

sub is_passive {
    my ($t_node) = @_;
    return (  ( $t_node->get_lex_anode and $t_node->get_lex_anode->tag =~ /^Vs/ )
        or is_refl_pass($t_node)
    ) ? 1 : 0;
}

sub in_byt_videt {
    my ($t_node) = @_;
    my ($epar) = $t_node->get_eparents( { or_topological => 1 } ) if ( $t_node );
    return ( $epar
        and ($epar->t_lemma || "") eq "být"
        and $t_node->t_lemma =~ /^(vidět|slyšet|cítit)$/
    ) ? 1 : 0;
}

sub predict_antec {
    my ( $cor_verb ) = @_;
    my $antec;
    my $cor_verb_lemma = $cor_verb->t_lemma;

    my ( $cphr ) = grep { $_->functor eq "CPHR" } $cor_verb->get_echildren( { or_topological => 1 } );
    if ( $cphr ) {
        $cor_verb_lemma .= "_" . $cphr->t_lemma;
    }

    if ( $cor_verb_lemma =~ /^($verb_list_ACT)$/ ) {
        ($antec) = grep { $_->functor eq "ACT" } $cor_verb->get_echildren( { or_topological => 1 } );
    }
    elsif ( $cor_verb_lemma =~ /^($verb_list_PAT)$/ ) {
        ($antec) = grep { $_->functor eq "PAT" } $cor_verb->get_echildren( { or_topological => 1 } );
    }
    elsif ( $cor_verb_lemma =~ /^($verb_list_ADDR)$/ ) {
        ($antec) = grep { $_->functor eq "ADDR" } $cor_verb->get_echildren( { or_topological => 1 } );
    }
    elsif ( $cor_verb_lemma =~ /^($verb_list_ORIG)$/ ) {
        ($antec) = grep { $_->functor eq "ORIG" } $cor_verb->get_echildren( { or_topological => 1 } );
    }
    elsif ( $cor_verb_lemma =~ /^($verb_list_BEN)$/ ) {
        ($antec) = grep { $_->functor eq "BEN" } $cor_verb->get_echildren( { or_topological => 1 } );
    }
    return $antec;
}

#   Antecedent is in coordination -> get the coordination node, the nearest to the control verbs
# e.g. závislost(predicted antec) -> #Comma -> či -> oddělovat(reciprocity verb) => či will be the coordination antec
sub get_coord_antec {
    my ($antec, $cor_verb) = @_;
    if ( $antec and grep { $_ eq $antec } $cor_verb->descendants ) {
        my $antec_par = $antec;
        while ( $antec_par->get_parent and $antec_par->get_parent ne $cor_verb ) {
            $antec_par = $antec_par->get_parent;
        }
        return $antec_par if ( $antec_par and ($antec_par->functor || "") =~ /^(APPS|CONJ|DISJ|GRAD)$/ );
    }
    return $antec;
}

# returns control verb
sub get_cor_verb {
    my ( $depend_verb ) = @_;
    my ($cor_verb) = $depend_verb->get_eparents( { or_topological => 1 } );
    if ( $cor_verb and not $cor_verb->is_generated 
        and not in_byt_videt($cor_verb, $depend_verb)
        and (($cor_verb->gram_sempos || "") eq "v" 
        or $cor_verb->functor eq "CPHR") ) {
        if ( $cor_verb->functor eq "CPHR" ) {
            my ($epar) = $cor_verb->get_eparents( { or_topological => 1 } );
            return $epar;
        }
        return $cor_verb;
    }
    else {
        return;
    }
}

sub process_tnode {
    my ( $self, $t_node ) = @_;
    
    my $cor_functor;
    my $predict_antec;
#     searching for t_nodes = dependent verbs
    if ( is_infinitive($t_node)
        and not $t_node->is_generated
        and $t_node->functor eq "PAT" )
    {
        my $depend_verb = $t_node;
        my $cor_verb = get_cor_verb($depend_verb);
        if ( $cor_verb ) {
            $predict_antec = predict_antec($cor_verb);
            if ( $predict_antec ) {
                $cor_functor = ( is_passive($depend_verb) ) ? "PAT" : "ACT";
                my $new_node = $depend_verb->create_child;
                $new_node->set_t_lemma('#Cor');
                $new_node->set_functor($cor_functor);
                $new_node->set_formeme('drop');

                #$new_node->set_attr( 'ord',     $t_node->get_attr('ord') - 0.1 );
                #$new_node->set_id($t_node->generate_new_id );
                $new_node->set_nodetype('complex');
                $new_node->set_gram_sempos('n.pron.def.pers');
                $new_node->set_is_generated(1);
                $new_node->shift_before_node($depend_verb);
                $predict_antec = get_coord_antec($predict_antec, $cor_verb);
                $new_node->set_deref_attr( 'coref_gram.rf', [$predict_antec] );
            }
        }
#         print $t_node->get_address . "\n";
    }
}

1;

=over

=item Treex::Block::A2T::CS::AddCor

1. Adds reconstructed prodropped nodes with t-lemma #Cor (control constructions)
2. Adds a coreferential link from the newly reconstructed #Cor node to its antecedent taking coordination into account


=back

=cut

# Copyright 2011 Nguy Giang Linh

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
