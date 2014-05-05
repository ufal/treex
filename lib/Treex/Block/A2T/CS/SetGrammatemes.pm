package Treex::Block::A2T::CS::SetGrammatemes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
use utf8;

# Delete all previously set grammatemes, or overwrite only ?
has 'delete_previous' => ( isa => 'Bool', is => 'ro', default => 0 );

use Treex::Tool::Lexicon::CS;
use Treex::Tool::Lexicon::CS::Aspect;
use Treex::Tool::Lexicon::CS::Adverbia;

# odchylky od puvodniho bloku:
# 1) aspekt se vyplnuje pomoci Treex::Tool::Lexicon::Cs:Aspect::get_verb_aspect, ktery vraci 'P' kdyz nevi (puvodni blok vracel I)
# 2) possadj_to_noun se resi v bloku A2T::CS::FixTlemmas, ten ale lemmata lowercasuje
# 3) conversion rules prevedeny do souboru, ktery je zatim ve stejnem adresari spolecne s blokem

my %applicable_gram;
my %all_applicable_grams;
my %t_lemma2attribs;    # hodnoty atributu, ktere se maji vyplnit na zaklade hodnoty t_lemmatu
my %origrule;
my %premise;            # seznam moznych premis

sub _my_dir {
  return dirname((caller)[1]);
}
get_conversion_rules_from_file(_my_dir() . "/conversion_rules.txt");

my %tnumber2gnumber = ( 'S' => 'sg', 'P' => 'pl', 'D' => 'pl' );
my %tgender2ggender = ( 'F' => 'fem', 'I' => 'inan', 'M' => 'anim', 'N' => 'neut' );

# podruhe: preklad casti tagu na hodnotu gramatemu (navazuje na tabulky u set_gn...
my %tdegree2gdegree   = ( '1' => 'pos',  '2' => 'comp', '3' => 'sup', '-' => 'pos' );
my %tnegat2gnegat     = ( 'A' => 'neg0', 'N' => 'neg1', '-' => 'neg0' );
my %ajkaaspect2aspect = ( 'P' => 'cpl',  'I' => 'proc', 'B' => 'nr' );

# hodnoty deonticke modality podle lemmatu skryteho slovesa
my %lemma2deontmod = (
    'muset'   => 'deb',
    'mít'    => 'hrt',
    'chtít'  => 'vol',
    'hodlat'  => 'vol',
    'moci'    => 'poss',
    'dát_se' => 'poss',
    'dát'    => 'poss',    # (pro jistotu)
    'smět'   => 'perm',
    'dovést' => 'fac',
    'umět'   => 'fac'
);

# rody nekterych cislovek vyjadrenych slovem
my %numerallemma2gender = (
    'sto'      => 'neut',
    'tisíc'   => 'inan',
    'milion'   => 'inan',
    'milión'  => 'inan',
    'miliarda' => 'fem',
    'bilion'   => 'inan',
    'bilión'  => 'inan'
);

my %nonnegable_semn;
map { $nonnegable_semn{$_} = 1 } qw(
    glasnost Hnutí hnutí hodnost Host host Husajní Husní Chomejní Investiční
    jakost jmění kamení kontilití Kost kost krveprolévání krveprolití lešení
    listí Martí mezipřistání místnost monopost Most most náčiní nadání Náměstí
    náměstí nanebevstoupení napětí národnost návštěvnost Nedorost nerost neštěstí
    Nevolnost oddělení okolnost osobnost paní pidiosobnost Pobaltí podezření
    podnikání podsvětí pokání pokolení pololetí ponětí porodnost porost Porýní
    post prazkušenost prodlení Prost proticírkevnost protiopatření předloktí
    předměstí přednost představení příčestí příjmení příležitost pseudoživnost
    půlstoletí působnost Rabbání rádio_aktivní radní radost rčení recepční rozhraní
    ručení rukoudání sebehodnocení sebeobětování sebeomezení sebepoznání sebeupálení
    sebeurčení sebezahleděnost sebezkoumání sebezničení sepjetí skvost soustátí
    společnost Srní stání starost státnost století štěstí Štětí televizní tisíciletí
    trnkobraní trojutkání účetní úmrtí úpatí uskupení ustanovení Ústí ústraní
    utrpení vedení vězení vlastnost vrchní výsluní výsost vysvědčení Záblatí
    zákoutí záležitost Zámostí zápěstí Zápotoční zemětřesení zmrtvýchvstání
    znakování znamení Znouzecnost znovunavrácení znovuzačlenění znovuzavedení
    zvláštnost žádost živobytí);

sub process_ttree {
    my ( $self, $t_root ) = @_;

    my %adjectival = ();    # mazani cache #!!!

    # delete all previously filled grammatemes, if supposed to
    if ( $self->delete_previous ){
        foreach my $t_node ( $t_root, $t_root->descendants ) {
            $t_node->set_attr( 'gram', undef );
        }
    }

    my $temp_attrs = get_temporary_attributes($t_root);

    foreach my $t_node ( $t_root, $t_root->descendants ) {

        if ( $t_node->nodetype eq 'complex' ) {
            assign_automatic_grammatemes( $t_node, $temp_attrs );
            apply_conversion_rules($t_node);    # aplikace konverznich pravidel z externiho deklaracniho souboru
            apply_postprocessing( $t_node, $temp_attrs );    # dodatecne upravy (dalsi automaticka pravidla)
            fill_missing_grammatemes($t_node);               # vyplni nr do zbyvajicich relevantnich (zatim prazdnych) gramatemu
        }

        #      ustrnule_slovesne_tvary($node);                # specialni osetreni ustrnulych participii a prechodniku
        remove_superfluous_grammatemes($t_node);             # vyprazdni hodnotu nerelevantnich gramatemu
    }

    #    clean_temporary_attributes($root);
    assign_sentmod( $t_root, $temp_attrs );
}

sub get_conversion_rules_from_file {
    my $filename = shift;

    open( CONVERSION_RULES, "<:utf8", $filename ) or log_fatal "Can't find $filename.";
    my $configtext = "";
    while (<CONVERSION_RULES>) {
        $configtext .= $_;
    }

    $configtext =~ s/#.+?\n//g;
    $configtext =~ s/if\s+(\S+)/if\($1\)/sxmg;    # ?
    $configtext =~ s/\s+//smxg;
    $configtext =~ s/wordclass/sempos/ig;
    $configtext =~ s/trlemma/t_lemma/ig;
    $configtext =~ s/,[^a-zA-Z0-9_]+/,/gsxm;

    #if (not $configtext=~/\s/) {
    #  print STDERR "Neni zadna mezera v :   |$configtext|\n";
    #  exit;
    #}

    foreach my $commandline ( split ";", lc($configtext) ) {

        if ( $commandline =~ /^([a-z,0-9,\,]+):((([a-z,0-9,.])+)(,([a-z,0-9,.])+)*)$/ ) {    # possible values
                                                                                             # uz neni potreba, bylo to tam jen kvuli upravam hlavicek ve fs
        }
        elsif ( $commandline =~ /^([a-z,0-9,\.]+)\=\>(((([a-z,0-9,.])+)?(,([a-z,0-9,.])+)*))$/ ) {    # atributy u wordclassu
            my $sempos = $1;
            my @grams = split ",", $2;

            if (@grams) {
                foreach (@grams) {
                    $applicable_gram{$sempos}{$_} = 1;
                    $all_applicable_grams{$_} = 1;
                }
            }
            else {
                %{ $applicable_gram{$sempos} } = ();
            }

        }
        elsif ( $commandline =~ /^(if\((\S+)\))?([^-()]+)\-\>(([a-z,0-9,_]+=[^,]+,?)*)$/ ) {    # co vyplyva primo z trlemmatu
            my $premise = $2 || "";
            my $lemmas  = $3;
            my $attribs = $4;

            # FIXME find some solution for commandlines without any premise filled (premise = 'in any case' ?)
            foreach my $l ( split ",", $lemmas ) {
                $t_lemma2attribs{$l}{$premise} = $attribs;
                $origrule{$l}{$premise}        = $commandline;
            }
        }
        elsif ( $commandline =~ /^\((\S+)\)$/ ) {                                               # deklarace moznych premis
            $premise{$1} = 1;
        }

        else {
            log_warn "$commandline\nUnrecognized line in the config file:\n|$commandline|\n";
        }
    }
}

# centralni procedura pro vyplneni gramatemu u komplexnich uzlu
sub assign_automatic_grammatemes {
    my ( $t_node, $temp_attrs ) = @_;

    my $tag = $$temp_attrs{$t_node}{lex_tag};
    my ( $tpos, $tsubpos, $tgender, $tnumber, $tcase, $tposgender, $tposnumber, $tperson, $ttense, $tdegree, $tnegat ) = split "", $tag;
    my $t_lemma = $t_node->t_lemma;
    my $form    = $$temp_attrs{$t_node}{lex_form};
    my $m_lemma = $$temp_attrs{$t_node}{lex_lemma};
    $m_lemma =~ s/(.+)([-_`].+)/$1/g;
    my $functor = $t_node->functor;

    my $parent;
    if ( $t_node->get_parent && !$t_node->is_coap_root ) {
        ($parent) = $t_node->get_eparents( { or_topological => 1 } );
    }

    # ------------- jednotlive tridy komplexnich uzlu -----------

    if ( $t_node->t_lemma eq "#EmpNoun" ) {
        $t_node->set_gram_sempos('n.pron.def.demon');    # X011
        set_gn_by_adj_agreement( $t_node, 'gender', $temp_attrs );
        set_gn_by_adj_agreement( $t_node, 'number', $temp_attrs );
    }

    #  adjektiva udelana ze slovesnych pricesti
    elsif ( $tag =~ /^V/ and $t_node->t_lemma =~ /[ýí]$/ ) {
        $t_node->set_gram_sempos('adj.denot');           # X012
        $t_node->set_gram_degcmp('pos');                 # X013
        ###    set_attr($t_node,'gram/negation',$tnegat2gnegat{$tnegat});
    }

    # ciselne vyrazy nejrozlicnejsich tagu, ktere ale chceme zpracovat po svem (osetreno vice_mene)
    elsif (
        $t_lemma !~ /_/ and (
            $t_lemma =~ /^(málo|nemálo|mnoho|nemnoho|hodně|nejeden|bezpočet|bezpočtu)$/
            or
            ( $tag =~ /^[^N]/ and $t_lemma =~ /^(moc|pár)$/ )
        )
        )
    {
        $t_node->set_gram_sempos('adj.quant.grad');    #X014
        my $degree = $tdegree2gdegree{$tdegree};
        $degree = "pos" unless $degree;
        $t_node->set_gram_degcmp($degree);             #X015
        $t_node->set_gram_numertype('basic');          #X016
    }

    # castice "asi" a "až"
    elsif ( $t_lemma =~ /^(asi|až|ani|i|nehledě|jen|jenom)$/ ) {
        $t_node->set_gram_sempos('adv.denot.ngrad.nneg');    #X017
    }

    # -------------- osobni zajmena

    # ---- A.1. (i) povrchove realizovana osobni zajmena

    elsif ( $tag =~ /^P[P5H]/ && $t_node->get_lex_anode ) {
        $t_node->set_t_lemma('#PersPron');
        $t_node->set_gram_sempos('n.pron.def.pers');
        $t_node->set_gram_person($tperson);
        $t_node->set_attr( 'gram/number', $tnumber2gnumber{$tnumber} );
        $t_node->set_gram_politeness('basic');
        if ( $tperson eq '3' ) {
            if ( $tgender2ggender{$tgender} ) {
                $t_node->set_attr( 'gram/gender', $tgender2ggender{$tgender} );
            }
            else {

                #	  set_gn_by_verb_agreement($t_node,'gender')
            }
        }
        else {
            set_gn_by_verb_agreement( $t_node, 'gender', $temp_attrs );
        }
    }

    # ---- A.1. (ii) povrchove nerealizovana osobni zajmena (??? to je cele divne, ty asi nebudou nijak odlisena)

    elsif ( $t_lemma =~ /^(já|my|ty|vy|on|#PersPron)$/ && !$t_node->get_lex_anode ) {
        $t_node->set_gram_sempos('n.pron.def.pers');
        set_gn_by_verb_agreement( $t_node, 'number', $temp_attrs );
        set_gn_by_verb_agreement( $t_node, 'gender', $temp_attrs );
        $t_node->set_gram_politeness('basic');
        $t_node->set_gram_person('3');

        #??? dodelat osoby
        #       set_attr($t_node,'t_lemma','#PersPron');

        #       set_attr($t_node,'gram/politeness','basic');

        #       # person
        #       if ($m_lemma=~/(já|my)/) {
        # 	set_attr($t_node,'gram/person','1');
        #       }
        #       elsif ($m_lemma=~/(ty|vy)/) {
        # 	set_attr($t_node,'person','2');
        #       }
        #       else {
        # 	set_attr($t_node,'person','3');
        #       };

        #       # number
        #       if ($t_node->{number}=~/^(SG|PL)/) {   # kde by se tu vzal???
        # 	set_attr($t_node,'number',lc($t_node->{number}));
        #       }
        #       else {
        # 	set_gn_by_verb_agreement($t_node,'number');
        #       }

        #       # gender
        #       if ($t_lemma eq "on" and $t_node->{gender}=~/^(ANIM|INAN|FEM|NEUT)/) {
        # 	set_attr($t_node,'gender',lc($t_node->{gender}))
        #       } else {
        # 	set_gn_by_verb_agreement($t_node,'gender');
        # #	manual ($t_node,'gender');
        #       }
    }

    # ---- A.2. posesivni zajmena
    elsif ( $tag =~ /^PS/ ) {
        $t_node->set_attr( 't_lemma', '#PersPron' );
        $t_node->set_gram_sempos('n.pron.def.pers');
        $t_node->set_gram_person($tperson);
        $t_node->set_gram_politeness('basic');
        $t_node->set_attr( 'gram/number', $tnumber2gnumber{$tposnumber} );
        if ( $tperson eq "3" ) {
            if ( $tgender2ggender{$tposgender} ) {
                $t_node->set_attr( 'gram/gender', $tgender2ggender{$tposgender} );
            }
        }
    }

    # --- zvratna zajmena
    elsif ( $tag =~ /^P[678]/ and $t_node->functor ne "DPHR" ) {
        $t_node->set_t_lemma('#PersPron');
        $t_node->set_gram_sempos('n.pron.def.pers');
        $t_node->set_gram_number('inher');
        $t_node->set_gram_gender('inher');
        $t_node->set_gram_person('inher');
        $t_node->set_gram_politeness('inher');
        $t_node->set_attr( 'is_reflexive', 1 );
    }

    # --- A.3. posesivni adjektiva
    elsif ( $tag =~ /^AU/ ) {
        $t_node->set_gram_sempos('n.denot');

        # TOHLE SE RESI v BLOKU FixTlemmas
        #        if ( $t_lemma =~ /^(.+)_/ ) {    # von_Ryanuv, de_Gaulluv
        #            my $prefix = $1;
        #            $t_node->set_t_lemma( $prefix . "_" . Fill_grammatemes::possadj_to_noun( $m_lemma ) );
        #        }
        #        else {                           # Masarykuv
        #            $t_node->set_t_lemma( Fill_grammatemes::possadj_to_noun( $m_lemma ) );
        #        }
        $t_node->set_gram_number('sg');
        $t_node->set_attr( 'gram/gender', $tgender2ggender{$tposgender} );
    }

    # --- A.4. prevadeni adjektiv vzniklych z adverbii apod. --- to se nebude delat

    # B.5 a B.8
    elsif ( $t_lemma =~ /^(tisíc|mili.n|miliarda|bili.n)$/ ) {

        #      set_attr($t_node,'t_lemma',$t_lemma);
        $t_node->set_gram_sempos('n.quant.def');
        $t_node->set_gram_numertype('basic');
        $t_node->set_attr( 'gram/gender', $numerallemma2gender{$t_lemma} );
        $t_node->set_attr( 'gram/number', $tnumber2gnumber{$tnumber} );
    }
    elsif ( $t_lemma eq "sto" ) {

        #      set_attr($t_node,'t_lemma',$t_lemma);
        $t_node->set_gram_sempos('n.quant.def');
        $t_node->set_gram_numertype('basic');
        $t_node->set_gram_gender('neut');
        if ( $form =~ /^(sto|stu|stem|sta)/ ) {
            $t_node->set_gram_number('sg');
        }
        else {
            $t_node->set_gram_number('pl');
        }
    }

    # --- B.1. pojmenovaci substantiva
    elsif ( $tag =~ /^N/ ) {

        if ( $t_lemma =~ /(ní|tí|ost)$/ and not $nonnegable_semn{$t_lemma} ) {
            $t_node->set_gram_sempos('n.denot.neg');

            #	set_attr($t_node,'gram/negation',$tnegat2gnegat{$tnegat});
        }
        else {
            $t_node->set_gram_sempos('n.denot');
        }

        #      set_attr($t_node,'t_lemma',$t_lemma);
        $t_node->set_attr( 'gram/gender', $tgender2ggender{$tgender} );
        $t_node->set_attr( 'gram/number', $tnumber2gnumber{$tnumber} );

        #      if (not $tnumber2gnumber{$tnumber} and   ### ???? was war tas?
        #	  $t_node->{_t_lemma_}=~/^.R$/ and $t_node->{tag}=~/^..F/) {
        #	set_attr($t_node,'number','sg');
        #      }

        if ( $$temp_attrs{$t_node}{lex_afun} eq 'Sb' && $tag =~ /^V/ ) {    # doplneni rodu a cisla (pokud chybi), ze shody se slovesem
            my $changed;
            if ( $t_node->attr('gram/gender') =~ /^(|nr)$/ ) {
                set_gn_by_verb_agreement( $t_node, 'gender', $temp_attrs );
                $changed++;
            }
            if ( $t_node->attr('gram/number') =~ /^(|nr)$/ ) {
                set_gn_by_verb_agreement( $t_node, 'number', $temp_attrs );
                $changed++;
            }

            #	Position if $changed;

        }
    }

    # --- B.5 ----
    elsif ( $tag =~ /^Cd/ ) {
        $t_node->set_gram_sempos('adj.quant.def');
        if ( $form =~ /.+jí/i ) {    # dvoji, troji, oboji
            $t_node->set_gram_numertype('kind');
        }
        else {                        # dvoje, troje, oboje
            $t_node->set_gram_numertype('set');
        }
    }
    elsif ( $tag =~ /^C[ln]/ ) {      # zakladni: jedna,dve, Honza de
                                      #      set_attr($t_node,'t_lemma',$t_lemma); ?
        if ($functor !~ /COMPL|EFF|RSTR/
            and not
            ( $functor eq "PAT" and $parent->get_lex_anode && $parent->get_lex_anode->lemma eq "být" )
            )
        {
            $t_node->set_gram_sempos('n.quant.def');
            if ( $t_lemma eq "jeden" ) {
                $t_node->set_gram_number('sg')
            }
            else {
                $t_node->set_gram_number('pl')
            }
            $t_node->set_attr( 'gram/gender', $tgender2ggender{$tgender} );    # ??? od ctyrky to stejne nefunguje, vzal to cert
        }
        else {
            $t_node->set_gram_sempos('adj.quant.def');
        }
        $t_node->set_gram_numertype('basic');
    }
    elsif ( $tag =~ /^C=/ and $t_lemma =~ /^(.+)_(krát|x)$/ ) {               # puvodni t_lemma "158_krat" - asi predelat na AIDREFS
        $t_node->set_t_lemma($1);
        $t_node->set_gram_sempos('adj.quant.def');
        $t_node->set_gram_numertype('basic');

    }

    # cislice (arabske i rimske)
    elsif ( $tag =~ /^C[=}]/ ) {

        #    set_attr($t_node,'t_lemma',$t_lemma);

        if ($functor eq "RSTR"
            and $t_node->ord > $parent->ord
            and $parent->t_lemma && $parent->t_lemma =~ /^(rok|číslo|telefon|fax|tel|PSČ|paragraf|odstavec|odst|sbírka|č|zákon|vyhláška|sezona)$/
            )
        {
            $t_node->set_gram_sempos('n.quant.def');
            $t_node->set_gram_number('nr');
            $t_node->set_gram_gender('nr');
        }
        elsif ( adjectival($t_node) ) {
            $t_node->set_gram_sempos('adj.quant.def')
        }
        else {
            $t_node->set_gram_sempos('n.quant.def');
            $t_node->set_gram_number('nr');
            $t_node->set_gram_gender('nr');
        }

        if ( grep { $$temp_attrs{$_}{lex_form} eq "." } $t_node->children ) {    # radeji pres AIDREFS ???
            $t_node->set_gram_numertype('ord');
        }
        else {
            $t_node->set_gram_numertype('basic');
        }
    }
    elsif ( $tag =~ /^Cy/ ) {                                                    # pětina, wordclass a numertype a tlemma dostanou z konv.souboru
        $t_node->set_attr( 'gram/number', $tnumber2gnumber{$tnumber} );
        $t_node->set_attr( 'gram/gender', $tgender2ggender{$tgender} );

        # ptacek: ale jen pro 7 vyjmenovanych t-lemmat
        # proto wordclass a numertype vyplnuju nove i zde
        $t_node->set_gram_sempos('n.quant.def');
        $t_node->set_gram_numertype('frac');
    }
    elsif ( $tag =~ /^Ch/ ) {                                                    # jedny/nejedny
        $t_node->set_gram_sempos('adj.quant.def');
        $t_node->set_gram_numertype('set');
    }

    # substantivne pouzita adjektiva
    elsif ( $tag =~ /^A/ and $functor !~ /^(FPHR|ID)/ and not adjectival($t_node) and $parent->t_lemma !~ /[tn]í$/ ) {
        $t_node->set_gram_sempos('n.denot');
        $t_node->set_attr( 'gram/number', $tnumber2gnumber{$tnumber} );
        $t_node->set_attr( 'gram/gender', $tgender2ggender{$tgender} );
    }

    # --- B.6. adjektiva pojmenovavaci
    elsif ( $tag =~ /^A[AG2MC]/ ) {
        $t_node->set_gram_sempos('adj.denot');

        #      set_attr($t_node,'t_lemma',$t_lemma);
        $t_node->set_attr( 'gram/degcmp', $tdegree2gdegree{$tdegree} );

        #      set_attr($t_node,'gram/negation',$tnegat2gnegat{$tnegat});
    }

    # --- B.11-B.14 adverbia
    elsif ( $tag =~ /^D/ ) {

        #        if ( Treex::Tool::Lexicon::CS::Adverbia::get_adjective($t_lemma) ) {    # !!! vypnute prevadeni adverbii na adjektiva (v angl. to ted taky nedelam)
        #            $t_node->set_gram_sempos('adj.denot');
        #            $t_node->set_t_lemma( Treex::Tool::Lexicon::CS::Adverbia::get_adjective($t_lemma) );
        #            $t_node->set_attr( 'gram/degcmp',   $tdegree2gdegree{$tdegree} );
        #            $t_node->set_attr( 'gram/negation', $tnegat2gnegat{$tnegat} );
        #        }
        if ( Treex::Tool::Lexicon::CS::Adverbia::is_pronom($t_lemma) ) {    # tohle by se nikdy nemelo stat, to by mel prebit konverzni soubor!!!
            $t_node->set_gram_sempos('adv.pron.def');                       # 'adv.pron.???'
                                                                            #	set_attr($t_node,'t_lemma',$t_lemma);
        }
        elsif ( !Treex::Tool::Lexicon::CS::Adverbia::is_gradable($t_lemma) ) {
            if ( !Treex::Tool::Lexicon::CS::Adverbia::is_negable($t_lemma) ) {    # 1. nestupnovatelna nenegovatelna - alespon
                $t_node->set_gram_sempos('adv.denot.ngrad.nneg');
            }
            else {                                                                # 2. nestupnovatelna negovatelna - jinak
                $t_node->set_gram_sempos('adv.denot.ngrad.neg');
                $t_node->set_attr( 'gram/negation', $tnegat2gnegat{$tnegat} );
            }

            #	set_attr($t_node,'t_lemma',$t_lemma);

        }
        else {
            if ( !Treex::Tool::Lexicon::CS::Adverbia::is_negable($t_lemma) ) {    # 3. stupnovatelna nenegovatelna - pozde
                $t_node->set_gram_sempos('adv.denot.grad.nneg');
            }
            else {                                                                # 4. stupnovatelna negovatelna - rad
                $t_node->set_gram_sempos('adv.denot.grad.neg');
                $t_node->set_attr( 'gram/negation', $tnegat2gnegat{$tnegat} );
            }

            #	set_attr($t_node,'t_lemma',$t_lemma);
            $t_node->set_attr( 'gram/degcmp', $tdegree2gdegree{$tdegree} );
        }

    }

    # ------------- slovesa
    elsif ( $tag =~ /^V/ ) {
        $t_node->set_gram_sempos('v');

        $t_node->set_gram_iterativeness('it0');
        if ( $ajkaaspect2aspect{ Treex::Tool::Lexicon::CS::Aspect::get_verb_aspect($t_node->t_lemma) } ) {
            $t_node->set_gram_aspect( 
                $ajkaaspect2aspect{ Treex::Tool::Lexicon::CS::Aspect::get_verb_aspect($t_node->t_lemma) } 
                );
        }
        else {
            $t_node->set_gram_aspect('proc');    # TODO: Tohle nikdy nenastane, protoze get_verb_aspect vrati 'cpl', kdyz nevi
        }

        # pokud neni v seznamu, tak co!!!

        my @verb_a_nodes = grep { $_->tag =~ /^V/ } $t_node->get_anodes;

        if ( grep { $_->tag =~ /^V.........N/ } @verb_a_nodes ) {    # narozdil od PDT 2.0 je tu negace gramatem i u sloves!
                                                                     #	                               VpYS---XR-N
            $t_node->set_gram_negation('neg1');
        }
        else {
            $t_node->set_gram_negation('neg0');                      # narozdil od PDT 2.0 je tu negace gramatem i u sloves!
        }

        # --------- B.15. v.fin ------------------
        if ( grep { $_->tag =~ /^V[Bpqt]/ } @verb_a_nodes ) {        # !!!!!!! smazal jsem Vi a Vs

            # --- dispozicni modalita (anotuje se jen rucne)
            $t_node->set_gram_dispmod('disp0');

            # --- vyplneni verbmod a tense
            if ( grep { $_->tag =~ /^Vc/ or $_->lemma =~ /^(aby|kdyby)$/ } @verb_a_nodes ) {    # kondicional
                $t_node->set_gram_verbmod('cdn');
                if ( 1 < grep { $_->tag =~ /^Vp/ } @verb_a_nodes ) {
                    $t_node->set_gram_tense('ant');
                }
                else {
                    $t_node->set_gram_tense('sim');
                }
            }
            else {                                                                              # nekondicional -> indikativ
                $t_node->set_gram_verbmod('ind');
                $t_node->set_attr( 'gram/tense', tense( $t_node, $temp_attrs ) );
            }
        }

        # -------- B.16. v.imp -------------------------
        elsif ( any { $_->tag =~ /^Vi/ } @verb_a_nodes ) {
            $t_node->set_gram_dispmod('nil');
            $t_node->set_gram_verbmod('imp');
            $t_node->set_gram_tense('nil');
        }

        # -------- B.17. v.trans --------------
        elsif ( my $transgressive = first { $_->tag =~ /^V[em]/ } @verb_a_nodes ) {
            $t_node->set_gram_tense( $transgressive->tag =~ /^Vm/ ? 'ant' : 'sim' );
            $t_node->set_gram_dispmod('nil');
            $t_node->set_gram_verbmod('nil');
        }

        # -------- B.16. v.inf -------------------------
        else {
            $t_node->set_gram_dispmod('nil');
            $t_node->set_gram_verbmod('nil');
            $t_node->set_gram_tense('nil');
        }

        if ( $t_node->gram_verbmod eq '' ) {
            $t_node->set_gram_verbmod('nil');
        }
        if ( $t_node->gram_tense eq '' ) {
            $t_node->set_gram_tense('nil');
        }
        if ( $t_node->gram_dispmod eq '' ) {
            $t_node->set_gram_dispmod('nil');
        }

        # auxverbs!=verbnodes - samotne 'chtit' nebo 'muset' totiz nema dostat zadnou zvlastni modalitu

        my @auxverbs = grep { $_->tag =~ /^V/ } $t_node->get_aux_anodes;

        #      my @auxverbs=grep {$_ and $_->{tag}=~/^V/} map {$aid2node{$_}} (split /\|/,$t_node->{AIDREFS});

        # zjisteni deonticke modality
        my ($deontmod) = grep {$_} map { $_->lemma =~ /^([^_\-]+)/; $lemma2deontmod{$1} } @auxverbs;
        if ($deontmod) {
            $t_node->set_gram_deontmod($deontmod);
        }
        else {
            $t_node->set_gram_deontmod('decl');
        }

        # zjisteni resultativnosti
        if ( $$temp_attrs{$t_node}{lex_tag} =~ /^Vs/ and grep { $_->lemma =~ /^(mít)/ } @auxverbs ) {    # zruseno byt
            $t_node->set_gram_resultative('res1');
        }
        else {
            $t_node->set_gram_resultative('res0');
        }

    }

    # tohle je uz jen garbage
    #   elsif ($t_node->{func} eq "ID" or ($t_node->{tag}=~/^T/ and $t_node->{func}=~/^(ACT|PAT|EFF|ORIG)/)) {
    #     set_attr($t_node,'gram/sempos','n.denot');
    #     set_attr($t_node,'gender','nr');
    #     set_attr($t_node,'number','nr');
    #   }

    #   elsif ($t_node->{tag}=~/^[TI]/ and $t_node->{func}=~/(PAT|RSTR)/) {
    #     set_attr($t_node,'gram/sempos','adj.denot');
    #     set_attr($t_node,'degcmp','nr');
    #     set_attr($t_node,'negation','nr');
    #   }

    #   elsif ($t_node->{tag}=~/^I/ and $t_node->{func}=~/(PRED)/) {
    #     set_attr($t_node,'gram/sempos','v');
    #     set_attr($t_node,'verbmod','ind');
    #     set_attr($t_node,'deontmod','decl');
    #     set_attr($t_node,'dispmod','disp0');
    #     set_attr($t_node,'tense','sim');
    #     set_attr($t_node,'aspect','proc');
    #     set_attr($t_node,'resultative','res0');
    #     set_attr($t_node,'iterativeness','it0');
    #   }

    #   elsif ($t_node->{form} eq "=") {
    #     set_attr($t_node,'gram/sempos','v');
    #     set_attr($t_node,'verbmod','ind');
    #     set_attr($t_node,'deontmod','decl');
    #     set_attr($t_node,'dispmod','disp0');
    #     set_attr($t_node,'tense','sim');
    #     set_attr($t_node,'aspect','proc');
    #     set_attr($t_node,'resultative','res0');
    #     set_attr($t_node,'iterativeness','it0');
    #   }

    #   elsif ($t_node->{tag}=~/^[TI]/) {
    #     set_attr($t_node,'gram/sempos','n.denot');
    #     set_attr($t_node,'gender','nr');
    #     set_attr($t_node,'number','nr');
    #   }

    #   elsif ($t_node->{tag}=~/^X/ and "RSTR") {
    #     set_attr($t_node,'gram/sempos','adj.denot');
    #     set_attr($t_node,'degcmp','nr');
    #     set_attr($t_node,'negation','nr');
    #   }

    #   elsif (($t_node->{tag}=~/^X/ or $t_node->{_t_lemma_}=~/^(ad|do|ob)$/) and "PAR") {
    #     set_attr($t_node,'gram/sempos','n.denot');
    #     set_attr($t_node,'gender','nr');
    #     set_attr($t_node,'number','nr');
    #   }

    #   elsif ($t_node->{_t_lemma_} eq "a" and $t_node->{func} eq "RSTR") {
    #     set_attr($t_node,'gram/sempos','n.denot');
    #     set_attr($t_node,'gender','nr');
    #     set_attr($t_node,'number','nr');
    #   }

    #   elsif ($t_node->{_t_lemma_}=~/^pro(ti)?$/) {
    #     set_attr($t_node,'gram/sempos','n.denot');
    #     set_attr($t_node,'gender','nr');
    #     set_attr($t_node,'number','nr');
    #   }

    #   elsif ($t_node->{tag}=~/^R/ and $t_node->{func}=~/(EXT|DIR|LOC)/) { # spatne tagovane kolem,okolo
    #     set_attr($t_node,'gram/sempos','adv.denot.ngrad.nneg');
    #   }

    #   elsif ($t_node->{tag}=~/^R...\d/ and $t_node->{func}=~/(RSTR|ACT|TWHEN)/) { # spatne tagovane misto,po,k,z
    #     set_attr($t_node,'gram/sempos','n.denot');
    #     set_attr($t_node,'gender','nr');
    #     set_attr($t_node,'number','nr');
    #   }

    #   elsif ($t_node->{_t_lemma_}=~/^(de_facto|ad_hoc|a_podobně|a_priori|co_daleko|co_daleko_ten|co_dále_ten|co_dále|jednak|jenže|napospas|plus_minus|pokud_možný|zato)$/) {
    #     set_attr($t_node,'gram/sempos','adv.denot.ngrad.nneg');
    #   }

    #   elsif ($t_node->{tag}=~/^C/) {
    #       set_attr($t_node,'gram/sempos','adj.denot');
    #       set_attr($t_node,'degcmp','pos');
    #       set_attr($t_node,'negation','neg0');
    #   }

    else {        
        $t_node->set_gram_sempos('n.denot');
        log_warn('Unknown: ' . $t_node->t_lemma . ' ' . $t_node->get_address) if (!$tgender ||!$tnumber); 
        $t_node->set_attr( 'gram/gender', $tgender2ggender{$tgender} );
        $t_node->set_attr( 'gram/number', $tnumber2gnumber{$tnumber} );
    }
}    # end of assign_automatic_grammatemes

sub set_gn_by_adj_agreement {
    my ( $t_node, $attr, $temp_attrs ) = @_;

    my @adjectivals = grep { $$temp_attrs{$_}{lex_tag} =~ /^[APC][^Pd][^-][^-]/ } $t_node->get_echildren( { or_topological => 1 } );
    my $value;
    if ( $attr eq 'gender' ) {
        my ($tgenderadj) = map { $$temp_attrs{$_}{lex_tag} =~ /^..(.)/; $1 } grep { $$temp_attrs{$_}{lex_tag} =~ /^..[FNIM]/ } @adjectivals;
        if ($tgenderadj) {
            $value = $tgender2ggender{$tgenderadj};
            $t_node->set_gram_gender($value);
        }
    }
    elsif ( $attr eq 'number' ) {
        my ($tnumberadj) = map { $$temp_attrs{$_}{lex_tag} =~ /^...(.)/; $1 } grep { $$temp_attrs{$_}{lex_tag} =~ /^...[PS]/ } @adjectivals;

        if ( not $tnumberadj ) {
            if ( grep { $$temp_attrs{$_}{lex_tag} =~ /^C=/ and $$temp_attrs{$_}{lex_form} == 1 and $$temp_attrs{$_}{lex_ord} < $$temp_attrs{$t_node}{lex_ord} } @adjectivals ) {
                $tnumberadj = 'S'
            }
            elsif ( grep { $$temp_attrs{$_}{lex_tag} =~ /^C=/ and $$temp_attrs{$_}{lex_form} > 1 and $$temp_attrs{$_}{lex_ord} < $$temp_attrs{$t_node}{lex_ord} } @adjectivals ) {
                $tnumberadj = 'P'
            }
            elsif ( grep { $$temp_attrs{$_}{lex_tag} =~ /^(Dg|Cd)/ } @adjectivals ) {    # dvoje,hodne, malo, vice => plural
                $tnumberadj = 'P'
            }
        }
        if ($tnumberadj) {
            $value = $tnumber2gnumber{$tnumberadj};
            $t_node->set_gram_number($value);
        }
    }
    return $value;
}

sub set_gn_by_verb_agreement {

    my ( $t_node, $attr, $temp_attrs ) = @_;
    my ($parent) = $t_node->get_eparents( { or_topological => 1 } );

    if ($t_node->functor eq "ACT" and $parent->is_root    # jako ACT jsem kandidat na subjekt, protoze
        and ($temp_attrs->{$parent}{lex_tag} || '') =~ /^V[^s]/   # rodic je sloveso (ne v pasivu)
        and ($temp_attrs->{$t_node}{lex_tag} || '') !~ /^....[2-7]/    # pokud mam vubec tag a pad, neni to jiny nez nominativ
        and not grep { $_ ne $t_node and ( $temp_attrs->{$_}{lex_afun} eq "Sb" or $_->functor eq "ACT" ) } $parent->get_echildren( { or_topological => 1 } )    # a neni jiny kandidat
        )
    {

        #    my @verbnodes=grep {$_ and $_->{tag}=~/^V/} map {$aid2node{$_}} (split /\|/,($parent->{AIDREFS}||$parent->{AID}));

        my @verb_a_nodes = grep { $_->tag =~ /^V/ } $parent->get_anodes;

        # ??? tohle zlobi, nezjistuje to kategorie ze shody dobre
        #    print "QQQ1 verbanodes: anodes=".(join " ".map{$_->attr('form')}@anodes)." verbanodes=".(join " ".map{$_->attr('form')}@anodes)."\n";

        my $adjective;                                                                                                                                          # shoda se prejima pripadne i ze jmenne casti prisudku
        if ($parent->t_lemma eq "být"
            and
            ($adjective) = grep { $_->functor eq "PAT" and $$temp_attrs{$_}{lex_tag} =~ /^AA/ } $parent->get_echildren( { or_topological => 1 } )
            )
        {
            push @verb_a_nodes, $adjective->get_lex_anode();
        }

        my $changed;

        if ( $attr eq "gender" ) {

            my ($gender) = map { $_->tag =~ /^..(.)/; $1 } grep { $_->tag =~ /^..[FNIM]/ } @verb_a_nodes;

            if ($gender) {

                $t_node->set_attr( 'gram/gender', $tgender2ggender{$gender} );
                $changed++;
            }
            elsif (
                $t_node->gram_person eq "1"
                and
                ($gender) = map { $_->tag =~ /^..(.)/; $1 } grep { $_->tag =~ /^..[Y]/ } @verb_a_nodes
                )
            {
                $t_node->set_gram_gender('anim');
                $changed++;
            }
        }
        elsif ( $attr eq "number" ) {
            my ($number) = map { $_->tag; $1 } grep { $_->tag =~ /^...[PS]/ } @verb_a_nodes;
            if ($number) {
                $t_node->set_attr( 'gram/number', $tnumber2gnumber{$number} );
                $changed++;
            }
        }
        return $changed;
    }
    return 0;
}

# u finitnich slovesnych tvaru zjisti gramaticky cas 
# (pouziva se jen pro indikativ, zbytek se urcuje primo v assign_automatic_gramatemes)
sub tense {
    my ( $t_node, $temp_attrs ) = @_;
    my $tense;

    if ( $$temp_attrs{$t_node}{lex_tag} =~ /^V/ ) {
        my @verb_a_nodes = grep { $_->tag =~ /^V/ } $t_node->get_anodes;

        # jen pro finitni tvary
        if ( grep { $_->tag =~ /^V[Bpqt]/ } @verb_a_nodes ) {    #!!!!!!! ubral jsem zatim Vs a Vi

            # minuly cas
            if ( grep { $_->tag =~ /^Vp/ } @verb_a_nodes and not grep { $_->tag =~ /^Vc/ } @verb_a_nodes ) {
                $tense = 'ant'
            }

            # minuly kondicional - byval by prisel
            elsif (
                grep { $_->lemma !~ /^(být|bývat.*)$/ and $_->tag =~ /^Vp/ }
                @verb_a_nodes
                and grep { $_->lemma =~ /^(být|bývat.*)$/ and $_->tag =~ /^Vp/ } @verb_a_nodes
                and grep { $_->tag =~ /^Vc/ } @verb_a_nodes
                )
            {
                $tense = 'ant';
            }

            # budouci cas slozeny
            elsif (
                ( grep { $_->lemma eq "být" and lc( $_->form ) =~ /^(ne)?b/ and $_->tag =~ /^VB/ } @verb_a_nodes )
                and ( grep { $_->tag =~ /^Vf/ } @verb_a_nodes )
                )
            {
                $tense = 'post';
            }

            # budouci cas slovesa byt, budouci cas tvoreny prefixaci - pujdu,nepojedu...            
            # budouci cas perfektiv (v puvodnim bloku obsahoval chybu a neprovadel se)
            elsif (
                @verb_a_nodes == 1 and $verb_a_nodes[0]->tag =~ /^VB......([FP])/ 
                and ( $1 eq 'F' or  Treex::Tool::Lexicon::CS::Aspect::get_verb_aspect($t_node->t_lemma) eq 'P' )
                )
            {    
                $tense = 'post';
            }

            # budouci cas - trpny rod
            elsif (
                ( grep { $_->tag =~ /^Vs/ } @verb_a_nodes )
                and
                (   grep {
                        $_->lemma eq "být"
                            and $_->tag
                            =~ /^VB/
                            and lc( $_->form ) =~ /^(ne)?b/
                    } @verb_a_nodes
                )
                )
            {
                $tense = 'post';
            }

            # fallback pro zbytek
            else {
                $tense = 'sim';
            }

            # ?????
            #      if ($report){print "veta: ".PDT::get_sentence_string_TR()."\n".
            #	"slovesna forma: ".(join " ",map {$_->{form}} @verb_a_nodes)."\n".
            #	    "hlavni lemma: ".$node->{_t_lemma_}."\n".
            #	  "tense: $tense\naid: ".$node->{AID}."\n\n";}

            return $tense;
        }
    }
}

# dodatecne automaticke upravy (na zaklade toho, co se rozhodlo az konverznimi pravidly)
sub apply_postprocessing {
    my ( $t_node, $temp_attrs ) = @_;
    my ( $tpos, $tsubpos, $tgender, $tnumber, $tcase, $tposgender, $tposnumber, $tperson, $ttense, $tdegree, $tnegat ) = split '', $$temp_attrs{$t_node}{lex_tag};

    # pokud byly konverznimi pravidly rozeznany zlomkove vyrazy (tretina), je potreba
    # doplnit gender a number  ?????
    #  if ($node->attr('gram/sempos') eq "n.quant.def" and $node->{g_wordclass} eq "frac") {
    #    set_attr($node,'gender',$tgender2ggender{$tgender});
    #    set_attr($node,'number',$tnumber2gnumber{$tnumber});
    #  }

    # pokud byly konverznimi pravidly rozeznany uzly N.pron.indef
    if ( $t_node->gram_sempos eq "n.pron.indef" ) {
        if ( $t_node->gram_indeftype eq "relat" ) {
            $t_node->set_gram_gender('inher');
            $t_node->set_gram_number('inher');
            $t_node->set_gram_person('inher');
        }
        else {
            if ( $tgender2ggender{$tgender} ) {
                $t_node->set_attr( 'gram/gender', $tgender2ggender{$tgender} );
            }
            else {    # cosi je defaultne sing.neut.
                $t_node->set_gram_gender('neut');
            }

            if ( $tnumber2gnumber{$tnumber} ) {
                $t_node->set_attr( 'gram/number', $tnumber2gnumber{$tnumber} );
            }
            else {
                $t_node->set_gram_number('sg');
            }

            $t_node->set_gram_person('3');

            if ( $$temp_attrs{$t_node}{lex_tag} =~ /^PQ/ ) {
                $t_node->set_gram_gender('neut');
                $t_node->set_gram_number('sg');
            }
        }
    }

    if ( $t_node->gram_sempos eq "n.pron.def.demon" ) { # tgender and tnumber might be undefined for #EmpNoun        
        $t_node->set_attr( 'gram/gender', $tgender2ggender{$tgender} ) if ($tgender && $tgender2ggender{$tgender});
        $t_node->set_attr( 'gram/number', $tnumber2gnumber{$tnumber} ) if ($tnumber && $tnumber2gnumber{$tnumber});
    }

    # gramatem negation u pojmenovacich uzlu
    if ( $t_node->gram_sempos =~ /denot/ ) {
        if ( $$temp_attrs{$t_node}{lex_tag} =~ /^..........N/ ) {

            #      print "sempos=".$t_node->gram_sempos."\n";
            $t_node->set_gram_negation('neg1');
        }
        else {
            $t_node->set_gram_negation('neg0');
        }
    }

    # nastaveni (pripadne prepsani) osoby, cisla a rodu podle shody podmetu s prisudkem
    if ( $t_node->gram_sempos eq "n.pron.indef" ) {
        set_indefpron_pgn_by_verb_agreement( $t_node, $temp_attrs );
    }

    # nastaveni dosud nevyplneneho  cisla a rodu u vsech semantickych substantiv v sub. pozici podle shody se slovesem.
    if ($t_node->gram_sempos and (
            !$t_node->gram_gender
            or !$t_node->gram_number
            or $t_node->gram_gender =~ /^(|nr)$/ or $t_node->gram_number =~ /^(|nr)$/
        )
        )
    {
        set_missing_gn_by_verb_agreement( $t_node, $temp_attrs );
    }

    # nastaveni dosud nevyplneneho rodu podle shody s adjektivem
    if ( $t_node->gram_sempos && $t_node->gram_sempos =~ /^n/ && ( !$t_node->gram_gender || $t_node->gram_gender =~ /^(|nr)$/ ) ) {    #and $node->{AID} ???
        if ( set_gn_by_adj_agreement( $t_node, 'gender', $temp_attrs ) ) {

            #      print "ggg\t$node->{form}\t$t_node->get_attr('gram/sempos'\t";Position;  # overeno
        }
    }

    # nastaveni dosud nevyplneneho cisla podle shody s adjektivem
    if ( $t_node->gram_sempos && $t_node->gram_sempos =~ /^n/ && ( !$t_node->gram_number || $t_node->gram_number =~ /^(|nr)$/ ) ) {    #  and $node->{AID} ???
        if ( set_gn_by_adj_agreement( $t_node, 'number', $temp_attrs ) ) {

            #      print "nnn\t$node->{form}\t$t_node->get_attr('gram/sempos'\t";Position; # overeno
        }
    }

    #   # doplneni chybejiciho gender/number u uzlu PersPron na zaklade koreference (dedi se z antecedentu)
    #   # (mela by tu nastat jen textova)
    #   # !!! doplnit pretahovani korefence i opacnym smerem
    #   # (a zkontrolovat, proc se podle koreference nededi pres hranice vety)
    #   my $id=$node->{TID}||$node->{AID};
    #   my $antec=$id2node{$node->{coref}};
    #   if ($node->{t_lemma} eq "&PersPron;" and ($node->{g_number}=~/^(|nr)$/ or $node->{g_gender}=~/^(|nr)$/)
    #       and $node->{coref} and $id2node{$node->{coref}}) {
    #     my $changed;
    #     if ($antec->{g_number} and $antec->{g_number}!~/nr|inher/ and $node->{g_number}=~/^(|nr)$/) {
    #       set_attr($node,'number',$antec->{g_number});
    #       $changed++;
    #       if ($report){print "EEE\t";Position();}
    #     }
    #     if ($antec->{g_gender} and $antec->{g_gender}!~/nr|inher/ and $node->{g_gender}=~/^(|nr)$/) {
    #       set_attr($node,'gender',$antec->{g_gender});
    #       $changed++;
    #       if ($report) {print "EEE\t";Position();}
    #     }
    #     if ($antec->{tag}=~/^V/) {
    #       if ($node->{g_gender}=~/^(|nr)$/) {
    # 	set_attr($node,'gender','neut');
    # #	Position;
    #       }
    #       if ($node->{g_number}=~/^(|nr)$/) {
    # 	set_attr($node,'number','sg');
    # #	Position;
    #       }
    #     }
    # #    Position if $changed;
    #   }

    #   if ($node->{t_lemma} eq "ten" and ($t_node->gram_number=~/^(|nr)$/ or $t_node->gram_gender=~/^(|nr)$/)  and $antec) {
    #     my $changed;
    #     if ($antec->{g_number} and $antec->{g_number}!~/nr|inher/ and $node->{g_number}=~/^(|nr)$/) {
    #       set_attr($node,'number',$antec->{g_number});
    #       $changed++;
    #       if ($report){print "EEE\t";Position();}
    #     }
    #     if ($antec->{g_gender} and $antec->{g_gender}!~/nr|inher/ and $node->{g_gender}=~/^(|nr)$/) {
    #       set_attr($node,'gender',$antec->{g_gender});
    #       $changed++;
    #       if ($report) {print "EEE\t";Position();}
    #     }
    #     if ($antec->{tag}=~/^V/) {
    #       if ($node->{g_gender}=~/^(|nr)$/) {
    # 	set_attr($node,'gender','neut');
    # 	$changed++;
    #       }
    #       if ($node->{g_number}=~/^(|nr)$/) {
    # 	set_attr($node,'number','sg');
    # 	$changed++
    #       }
    #     }
    # #    Position if $changed;
    #   }

    if ( ( $t_node->gram_sempos || '' ) =~ /^n/ and $$temp_attrs{$t_node}{lex_tag} =~ /^PDZ/ and ( $t_node->gram_gender || '' ) =~ /^(|nr)$/ ) {
        $t_node->set_gram_gender('neut');
    }

    # vsechny zkopirovane komparativy, ktere maji mezi predky CPR, by mely mit stupen positiv a ne komparativ
    # (jde o casti podstromu zkopirovanych pro ucely zachyceni srovnani)
    #   if ($node->{temp_lex_tag}=~/^.........2/ and $node->{TID}) {
    #     my $n=$node;
    #     while ($n->parent) {
    #       $n=$n->parent;
    #       if ($n->{func} eq "CPR") {
    # 	set_attr($node,'degcmp','pos');
    # 	if ($report){print "FFFFFFFFFFFf\t";Position();}
    #       }
    #     }
    #   }

    #   # upravy lemmat
    #   if ($node->{t_lemma} eq "tak_zvaný") {set_attr($node,'trlemma','takzvaný')}
    #   if ($node->{t_lemma}=~/(\d+)_&Percnt;/) {set_attr($node,'trlemma',"$1_procentní");}

}    # end of apply_postprocessing

# doplneni hodnoty nr vsem gramatemum, ktere maji byt vyplnene na zaklade wordclass
sub fill_missing_grammatemes {
    my $t_node    = shift;
    my $wordclass = $t_node->gram_sempos;
    if ($wordclass) {
        if ( defined $applicable_gram{$wordclass} ) {
            foreach my $gram ( keys %{ $applicable_gram{$wordclass} } ) {
                if ( !$t_node->get_attr("gram/$gram") ) {
                    $t_node->set_attr( "gram/$gram", "nr" );
                }
            }
        }
    }
}

# vyprazdni gramatemy, ktere danemu uzlu podle wordclasu nenalezeji
sub remove_superfluous_grammatemes {
    my $t_node    = shift;
    my $wordclass = $t_node->gram_sempos;

    #foreach my $gram ( grep { !/sempos/ } grep { not $applicable_gram{$wordclass}{$_} } keys %all_applicable_grams ) {
    #    set_attr($node,"gram/$gram",undef,'X127'); # ??? zatim zakomentovano
    #}
}

# vyplneni sentmod pro deti technickeho korene, koreny primych recich (ziskane uvozovkovanim i jinak) a koreny PAR
sub assign_sentmod {
    my ( $root, $temp_attrs ) = @_;
    my @nodes = $root->get_echildren( { or_topological => 1 } );
    foreach my $node ( grep { $_->functor && $_->functor eq "PAR" } $root->get_descendants ) {
        my $par_root = $node;
        while ( $par_root->get_parent->functor && $par_root->get_parent->functor =~ /^(APPS|CONJ|DISJ|ADVS|CSQ|GRAD|REAS|CONFR|CONTRA|OPER)/ ) {
            $par_root = $par_root->get_parent;
        }
        push @nodes, $par_root;
    }

    foreach my $myroot (@nodes) {    #???? to je nejaky divny, to chce zkontrolovat
        my $sentmod;
        my ($aroot) = $myroot->get_anodes;
        if ( $$temp_attrs{$myroot}{lex_tag} =~ /Vi/ ) {
            $sentmod = 'imper';
        }

        # TODO: this is not reliable (better to check the very last a-node), let's use A2T::SetSentmod instead
        #    elsif ($aroot and grep {$_->attr('form') eq "?"} $aroot->children) { # opraveno dle M.Janicka
        elsif ( $aroot and grep { $_->form eq "?" } $aroot->get_parent->get_children ) {
            $sentmod = "inter";
        }
        else {
            $sentmod = 'enunc';
        }
        $myroot->set_attr( 'sentmod', $sentmod );
    }
}

sub get_temporary_attributes {
    my $t_root = shift;
    my %temp_attrs;

    foreach my $t_node ( $t_root->get_descendants ) {
        foreach my $key (qw(lex_tag lex_form lex_lemma lex_afun lex_ord relative_clause)) {
            $temp_attrs{$t_node}{$key} = '';
        }
        if ( $t_node->get_lex_anode ) {
            my $a_node = $t_node->get_lex_anode;
            $temp_attrs{$t_node}{lex_tag}   = $a_node->tag;
            $temp_attrs{$t_node}{lex_form}  = $a_node->form;
            $temp_attrs{$t_node}{lex_lemma} = $a_node->lemma;
            $temp_attrs{$t_node}{lex_afun}  = $a_node->afun;
            $temp_attrs{$t_node}{lex_ord}   = $a_node->ord;
        }
    }
    return \%temp_attrs;
}

# aplikace konverznich pravidel ziskanych z externiho deklaracniho souboru 'conversion_rules.txt'
# (podle techto pravidel se na zaklade puvodni hodnoty t_lemmatu vyplnuji nektere atributy)
sub apply_conversion_rules {
    my ( $t_node, $temp_attrs ) = @_;
    my $t_lemma = lc( $t_node->t_lemma );
    my $ord     = $$temp_attrs{$t_node}{lex_ord};

    #  if ($t_lemma eq "kolik") {
    #    if ($report) {print "RRR  ".PDT::get_sentence_string_TR($root)."\n";}
    #  };
    #  print "APL1\n";
    if ( $t_lemma2attribs{$t_lemma} ) {

        #    print "APL2\n";
        foreach my $premise ( keys %{ $t_lemma2attribs{$t_lemma} } ) {

            my $func = $t_node->functor;
            if ( $premise eq "" or evalpremise( $t_node, $premise ) ) {

                #	if ($t_lemma eq "ten") {if ($report){print "TEN: veta:".PDT::get_sentence_string_TR($root);}}
                #if ($report) {
                #    print "Zabralo!!", $t_lemma2attribs{$t_lemma}{$premise}, "\n";
                #}
                $t_node->set_attr( 'nodetype', 'complex' );
                foreach my $pair ( split /,/, $t_lemma2attribs{$t_lemma}{$premise} ) {
                    if ( my ( $name, $value ) = split /=/, $pair ) {
                        if ( $name eq "wordclass" ) {
                            $name = "sempos"
                        }
                        $t_node->set_attr( "gram/$name", $value );
                    }
                }
            }
            else {

                #                if ($report) {
                #                    print "Fail\n";
                #                }
            }
        }
    }
}

# pro uzly semn.pron.indef, ktere maji afun Sb a nejsou vztazne, doplni (prebije) person,gender,number  podle shody se slovesem
# (napr. ve vetach "Kdo jsem byla","Vsichni jste....")
sub set_indefpron_pgn_by_verb_agreement {
    my ( $t_node, $temp_attrs ) = @_;
    my ($parent) = $t_node->get_eparents( { or_topological => 1 } );

    if ( $t_node->gram_sempos eq "n.pron.indef" and $t_node->gram_person !~ /1|2|inher/ and $$temp_attrs{$t_node}{lex_afun} =~ /^Sb/ ) {

        my @verb_a_nodes = grep { $_->tag =~ /^V/ or $_->lemma =~ /^(aby|kdyby)/ } $t_node->get_anodes;

        my $adjective;
        if (( $parent->t_lemma || '' ) eq "být"
            and
            ($adjective) = grep { ( $_->functor || '' ) eq "PAT" and $$temp_attrs{$_}{lex_tag} =~ /^AA/ } $parent->get_echildren( { or_topological => 1 } )
            )
        {
            push @verb_a_nodes, $adjective->get_lex_anode;
        }

        my $change;

        my ($person) = grep {$_} map { $_->tag =~ /^V......([12])/; $1 } @verb_a_nodes;
        if ( $person and $person ne $t_node->gram_person ) {
            $t_node->set_gram_person($person);
            $change++;
        }

        my ($gender) = grep {$_} map { $_->tag =~ /^..([MINF])/; $tgender2ggender{$1} } @verb_a_nodes;
        if ( $gender and $gender ne $t_node->gram_gender ) {
            $t_node->set_gram_gender($gender);
            $change++;
        }

        my ($number) = grep {$_} map { $_->tag =~ /^...([PS])/; $tnumber2gnumber{$1} } @verb_a_nodes;
        if ( $number and $number ne $t_node->gram_number ) {
            $t_node->set_gram_number($number);
            $change++;
        }

        #    Position if $change;
    }
}

# pro veskera semanticka substantiva v subjektove pozici vyplni dosud chybejici gender/number podle shody se slovesem
sub set_missing_gn_by_verb_agreement {
    my ( $t_node, $temp_attrs ) = @_;

    #  my ($parent)=PDT::GetFather_TR($t_node);
    my ($parent) = $t_node->get_eparents( { or_topological => 1 } );
    if ( $t_node->gram_sempos =~ /^n/ and $$temp_attrs{$t_node}{lex_afun} =~ /^Sb/ and $t_node->t_lemma ne "#PersPron" ) {

        my @verb_a_nodes = grep { $_->tag =~ /^V/ or $_->lemma =~ /^(aby|kdyby)/ } $t_node->get_anodes;

        my $adjective;
        if (( $parent->t_lemma || '' ) eq "být"
            and
            ($adjective) = grep { ( $_->functor || '' ) eq "PAT" and $$temp_attrs{$_}{lex_tag} =~ /^AA/ } $parent->get_echildren( { or_topological => 1 } )
            )
        {
            push @verb_a_nodes, $adjective->get_lex_anode;
        }

        if ( ( $t_node->gram_gender || '' ) =~ /^(|nr)$/ ) {
            my ($gender) = grep {$_} map { $_->tag =~ /^..([MINF])/; $tgender2ggender{$1} } @verb_a_nodes;
            if ($gender) {
                $t_node->set_gram_gender($gender);
            }
        }

        if ( ( $t_node->gram_number || '' ) =~ /^(|nr)$/ and $parent eq $t_node->get_parent ) {    # cislo se neda spolehlive tahat, kdyz jde o koordinaci
            my ($number) = grep {$_} map { $_->tag =~ /^...([PS])/; $tnumber2gnumber{$1} } @verb_a_nodes;
            if ($number) {
                $t_node->set_gram_number($number);
            }
        }
    }
}

# vyhodnocovani podminek pouzitych v (puvodne externim) konverznim souboru
sub evalpremise {
    my ( $node, $condition ) = @_;

    #    if ($report) {
    #        print "Util::Eval premise: $condition\n";
    #    }
    my $plur = ( $node->gram_number && $node->gram_number =~ /pl/ );    # ???
    my $func = $node->functor;
    my $tag  = $node->get_lex_anode->tag;

    my $coref = $node->get_coref_gram_nodes();

    # kandidati na vztazna zajmena/prislovce dostanou take $coref=1
    my ($lparent) = $node->get_eparents( { or_topological => 1 } );
    if ($node->t_lemma =~ /^(který|jaký|jenž|kdy|kde|co|kdo)$/
        && $lparent->get_lex_anode
        && $lparent->get_lex_anode->tag =~ /^V/
        && $lparent->functor eq "RSTR"
        )
    {
        my ($lgrandpa) = $lparent->get_eparents( { or_topological => 1 } );
        if ($lgrandpa
            && $lgrandpa->get_lex_anode
            && $lgrandpa->get_lex_anode->tag =~ /^[PN]/
            )
        {
            $coref = 1;
        }
    }

    # ???? tady je potreba nafejkovat gramatickou koreferenci u vztaznych vet
    # DM: to uz se asi udelalo

    if ( $condition !~ /^(rstr|notrstr|coref|notcoref|plur|notplur|twhen|ttill|loc|dir3|n&notrstr|notn&notrstr|coref&rstr|coref&notrstr|notcoref&rstr|notcoref&notrstr|coref&plur|coref&notplur|notcoref&plur|notcoref&notplur)$/ ) {
        print "Unknown premise $condition !\n";
    }

    return (
        ( $condition eq "rstr" and adjectival($node) )
            or
            ( $condition eq "notrstr"  and not adjectival($node) ) or
            ( $condition eq "coref"    and $coref )                or
            ( $condition eq "notcoref" and !$coref )               or
            ( $condition eq "plur"     and $plur )                 or
            ( $condition eq "notplur"  and not $plur )             or
            ( $condition eq "twhen" and $func eq "TWHEN" ) or
            ( $condition eq "ttill" and $func eq "TTILL" ) or
            ( $condition eq "loc"   and $func eq "LOC" )   or
            ( $condition eq "dir3"  and $func eq "DIR3" )  or
            ( $condition eq "n&notrstr" and $tag =~ /^..N/ and not adjectival($node) ) or
            ( $condition eq "notn&notrstr"     and $tag !~ /^..N/ and not adjectival($node) ) or
            ( $condition eq "coref&rstr"       and $coref         and adjectival($node) )     or
            ( $condition eq "coref&notrstr"    and $coref         and not adjectival($node) ) or
            ( $condition eq "notcoref&rstr"    and not $coref     and adjectival($node) )     or
            ( $condition eq "notcoref&notrstr" and not $coref     and not adjectival($node) ) or
            ( $condition eq "coref&plur"       and $coref         and $plur )                 or
            ( $condition eq "coref&notplur"    and $coref         and not $plur )             or
            ( $condition eq "notcoref&plur"    and not $coref     and $plur )                 or
            ( $condition eq "notcoref&notplur" and not $coref     and not $plur )
        )
}

# zda je uzel v pozici syntaktickeho adjektiva
# vypocet je pomaly a opakuje se, proto vysledky cachuju

# TODO jestli to má skutečně dělat, to co se tu píše, tak to nedává smysl: je spousta adjektiv ve funkci synt. substantiva,
# přitom tady se označí každé adjektivum za synt. pozici adjektiva; navíc označuje spousta zájmen s funktorem EFF,
# krom toho by nemělo sahat na gram_sempos -- volá se ve chvíli, kdy je vyplňována (tj. nekonzistentní chování)
my %adjectival;

sub adjectival($) {
    my $t_node = shift;
    return $adjectival{$t_node} if defined $adjectival{$t_node};

    my ($parent) = ( $t_node->get_eparents( { or_topological => 1 } ) );

    $adjectival{$t_node} =
        (
        ( grep { $_->tag =~ /^A/ } $t_node->get_anodes )
            || ( defined $t_node->gram_sempos && $t_node->gram_sempos =~ /^n/ )
            || ( $t_node->functor =~ /EFF|RSTR/ )
            || ( $t_node->functor eq "COMPL" && $t_node->get_lex_anode && $t_node->get_lex_anode->tag !~ /^C[l=]/ )    # ???
            || (
            $t_node->functor eq "PAT"
            && ( !$parent->is_root && $parent->t_lemma =~ /^(být|bývat|zůstat|zůstávat|stát_se|stávat_se|#Emp|#EmpVerb)$/ )
            )
        );
    return $adjectival{$t_node};
}

1;

=over

=item Treex::Block::A2T::CS::SetGrammatemes

Grammatemes of Czech complex nodes are filled by this block, using
POS tags, info about auxiliary words, list of pronouns etc. Besides
the genuine grammatemes such as C<gram/number> or C<gram/tense>, also
the classification attribute C<gram/sempos> is filled.

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, David Marecek

# -------------------------------------------------------------------------------
# -------------------------------------------------------------------------------
# -------------------------------------------------------------------------------

# extracted from fill_grammatemes.ntred by Zdenek Zabokrtsky:
# ZDE ZBYLY POUZE METODY, KTERE V PUVODNIM BLOKU NEBYLY POUZIVANY

package Fill_grammatemes;

my %adv2adj;    # puvodni adjektivum
my $report;

# ---------------------------------------------------------------------------------------------
# participia a prechodniky se maji lematizovat formou TODO: v puvodnim bloku bylo zakomentovano a neprovadelo se
sub ustrnule_slovesne_tvary($) {
    my $node = shift;
    if ($node->{temp_lex_form} =~ /^(takřka|takříkajíc|chtě|leže|kleče|sedě|vstoje|vleže|vkleče|vsedě|vstávaje|lehaje|soudíc|soudě|soudíc|soudě|nehledíc|nehledě|nemluvě|vycházejíc|vycházeje|zahrnujíc|nedbajíc|nedbaje|nepočítajíc|počítajíc|nepočítaje|počítaje|vyjmouc|vyjímajíc|vyjímaje|takřka|takříkajíc|leže|kleče|sedě|vstoje|vleže|vkleče|vsedě|vstávaje|lehaje|chtě|chtíc|soudíc|soudě|nehledíc|nehledě|nemluvě|vycházejíc|vycházeje|zahrnujíc|nedbajíc|nedbaje|počítajíc|počítaje|nepočítajíc|nepočítaje|vyjmouc|vyjímajíc|vyjímaje|nevyjímajíc|nevyjímaje)$/i
        or ($node->{temp_lex_form} =~ /^(dejme|vzato|věřte|zaplať|nedej|víte|ví|je)$/
            and $node->{functor} eq "ATT" and grep { $_->{functor} eq "DPHR" } $node->children
        )
        or ($node->{temp_lex_form} =~ /^(věřím|věříme|tuším|tušíme|myslím|myslíme|doufám|doufáme|prosím|promiňte|poslechněte|víte)$/
            and $node->{functor} eq "ATT"
        )
        or ( lc( $node->{temp_lex_form} ) eq "nevidět" and grep { $_->{t_lemma} eq "co" and $_->{functor} eq "DPHR" } $node->children )
        or ( $node->{form} =~ /^(zahrnuje)$/ and $node->{functor} eq "COND" )
        )
    {
        set_attr( $node, 't_lemma', lc( $node->{temp_lex_form} ), 'X146' );
        if ( $node->{nodetype} eq "complex" ) {
            set_attr( $node, 'gram/sempos', 'adv.denot.ngrad.nneg', 'X147' )
        }
        if ($report) {
            print "UST\t";
            Position();
        }
    }
}

1;

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
