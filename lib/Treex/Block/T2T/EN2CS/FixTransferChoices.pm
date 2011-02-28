package Treex::Block::T2T::EN2CS::FixTransferChoices;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

use Lexicon::Czech;

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;
    my $lemma_and_pos = fix_lemma($cs_tnode);
    if ($lemma_and_pos) {
        my ( $new_lemma, $new_pos ) = split /#/, $lemma_and_pos;
        $cs_tnode->set_t_lemma($new_lemma);
        $cs_tnode->set_attr( 'mlayer_pos', $new_pos );
        $cs_tnode->set_t_lemma_origin('rule-Fix_transfer_choices');
    }
    my $new_formeme = fix_formeme($cs_tnode);
    if ($new_formeme) {
        $cs_tnode->set_formeme($new_formeme);
        $cs_tnode->set_formeme_origin('rule-Fix_transfer_choices');
    }
    return;
}

sub fix_lemma {
    my ($cs_tnode)  = @_;
    my $cs_tlemma   = $cs_tnode->t_lemma;
    my ($cs_parent) = $cs_tnode->get_eparents({or_topological=>1});

    return 'který#P' if $cs_tlemma eq 'tento' && $cs_parent->is_relclause_head;

    my $en_tnode = $cs_tnode->src_tnode or return;
    my $en_tlemma = $en_tnode->t_lemma;

    # oprava reflexiv (!!! lepe opravit uz ve slovniku)
    return "${cs_tlemma}_se#V" if $en_tlemma =~ /become|learn|happen/ && $cs_tlemma =~ /t$/;

    if ( $cs_tlemma =~ /(.+)_s[ie]$/ and $cs_tnode->is_passive ) {
        return "$1#V";
    }

    # this is probably due to wrong tagging/lemmatization in CzEng
    return 'peníze#N' if $cs_tlemma eq 'peníz';

    return;
}

sub fix_formeme {
    my ($cs_tnode)  = @_;
    my $cs_tlemma   = $cs_tnode->t_lemma;
    my $cs_formeme  = $cs_tnode->formeme;
    my ($cs_parent) = $cs_tnode->get_eparents({or_topological=>1});
    my $cs_parent_tlemma  = $cs_parent->t_lemma               || '#root';
    my $cs_parent_formeme = $cs_parent->formeme               || '#root';
    my $cs_pos            = $cs_tnode->get_attr('mlayer_pos') || '';
    my $cs_tree_parent    = $cs_tnode->get_parent();

    my $en_tnode    = $cs_tnode->src_tnode or return;
    my $en_formeme  = $en_tnode->formeme;
    my ($en_parent) = $en_tnode->get_eparents({or_topological=>1});

    if (( $cs_formeme eq 'n:2' or $cs_formeme eq 'n:poss' )
        and $en_formeme eq 'n:poss'
        and $cs_pos     eq 'A'
        )
    {
        return 'adj:attr';
    }

    # pod substantivy je akuzativ nahrazen genitivem
    return 'n:2' if $cs_formeme eq 'n:4' && $cs_parent_formeme =~ /^n/;

    # if there remained a noun that cannot be converted to possessive form
    return 'n:2' if $cs_formeme eq 'n:poss'
            and $cs_pos    ne 'P'
            and $cs_tlemma ne '#PersPron'
            and (
                $cs_tnode->get_children
                or not Lexicon::Czech::get_poss_adj($cs_tlemma)
                or ( $cs_tnode->get_attr('gram/number') || '' ) eq 'pl'
            );

    # "Harmonium's role" - God knows why maxent prefers n:attr in such cases
    return 'n:2' if $cs_formeme eq 'n:attr'
            and $en_formeme eq 'n:poss'
            and $cs_tnode->precedes( $cs_tnode->get_parent );

    return 'n:7' if $en_formeme =~ /n:by/ && $en_parent->is_passive;

    # 'love of him' --> 'jeho laska'
    return 'n:poss' if $cs_tlemma eq '#PersPron'
            && $cs_formeme eq 'n:2'

            #            && $cs_parent_tlemma !~ /ina$/ # hack: vetsina, mensina...
            && ($cs_tnode->precedes($cs_tree_parent)
                || ( $cs_tree_parent->get_attr('mlayer_pos') || '' ) eq 'N'
            );

    # 'I hate his comming late.' --> '... ze chodi pozde'
    return 'n:1' if $en_formeme eq 'n:poss'
            && $cs_parent_formeme =~ /(fin|rc)/;

    if ( $cs_formeme eq 'adj:attr' && $cs_pos eq 'N' ) {
        return 'n:attr' if $cs_tnode->is_name_of_person;
        return 'n:2';
    }

    return 'adj:attr' if $cs_formeme =~ /^v/ && $cs_pos eq 'A';
    return 'adj:attr' if $cs_formeme ne 'adj:attr' && $cs_tlemma eq 'některý';

    return 'v:fin' if $cs_formeme =~ /v:že/ && $cs_tnode->precedes($cs_tree_parent);

    return 'n:z+2' if $cs_formeme eq 'n:2'
            && $en_formeme =~ /n:of/
            && !$cs_tree_parent->is_root()
            && (( $cs_tree_parent->get_attr('mlayer_pos') || '' ) eq 'P'
                || $cs_tree_parent->t_lemma eq 'jeden'
            );

    return 'v:aby+fin' if $cs_formeme eq 'v:inf'
            && $cs_parent_formeme =~ /^v/
            && !_Verb_with_allowed_inf($cs_parent_tlemma);

    return 'n:de+1' if $cs_formeme =~ /n:de_,t/;    # !!! temporal fix because wrong formeme in CzEng

    # !!! these expletives are not treated properly in CzEng so far:
    return 'v:poté_co+fin' if $cs_formeme eq 'v:co+fin' and $en_formeme eq 'v:after+fin';

    # 'bude-li' --> 'jestli bude' (the first one is equivalent but more complicated to implement)
    return 'v:jestli+fin' if $cs_formeme eq 'v:li+fin';

    # only->jediny: rhematizer in English, but adjectival attribute in Czech
    if ( $cs_tlemma eq 'jediný' and $cs_formeme eq 'x' ) {
        $cs_tnode->set_nodetype('complex');
        $cs_tnode->set_attr( 'gram/sempos', 'adj.denot' );
        $cs_tnode->set_functor('RSTR');
        return 'adj:attr';
    }

    # !!! tohle zahodit, az se pretrenuje maxent (doted nemohl videt spojku 'when')
    return 'v:když+fin' if ( $en_formeme =~ /when\+/ and $cs_formeme =~ /fin/ );

    return 'adj:attr' if $cs_formeme eq 'n:2' && $cs_tlemma =~ /^ten(to)?$/
            && $cs_parent_formeme =~ /^n/ && $cs_tnode->precedes($cs_parent);

    return 'n:1' if $cs_formeme eq 'n:5';    # there are almost no vocatives in newspapers, unlike in CzEng

    return 'adv:' if $cs_pos eq 'D' and $cs_formeme =~ /n:(.+)\+/ and $1 ne "než";    # 'nez' is a conjunction indeed

    return;
}

sub _Verb_with_allowed_inf {
    my $verb = shift;
    $verb =~ s/_[si]//;
    return ( $verb =~ /(bát|bavit|běhat|běhávat|běžet|bolet|bránit|být|cestovat|cítit|cítívat|činit|činívat|dařit|dařívat|dát|dávat|dělat|dělávat|děsit|děsívat|diktovat|diktovávat|dlužit|doběhnout|dobíhat|dobývat|docházet|dojet|dojímat|dojít|dojíždět|dojmout|dokázat|dokazovat|donutit|doporučit|doporučovat|dopravit|dopravovat|doprovázet|doprovodit|dopřát|dopřávat|dostat|dostávat|dostavit|dostavovat|dotáhnout|dotahovat|dotknout|dotýkat|dovádět|dovážet|dovést|dovézt|dovolit|dovolovat|drát|drávat|dráždit|dráždívat|drtit|drtívat|fascinovat|hledět|hnát|hnout|hodit|hodlat|hodnotit|honit|hrnout|hřát|hřávat|hýbat|hýbnout|chodit|chodívat|chránit|chtít|chutnat|chutnávat|chybět|chybívat|chystat|jet|jezdit|jezdívat|jímat|jímávat|jít|jmout|kázat|klamat|klamávat|koukat|kouknout|kráčet|lákat|lekat|lekávat|létat|letět|líbit|litovat|mást|míchat|míchávat|mínit|mínívat|mít|mívat|mizet|moci|moct|motivovat|mrzet|mučit|mučívat|muset|musit|nabídnout|nabízet|nadchnout|nacházet|najít|nakázat|nakazovat|naladit|nalaďovat|náležet|namáhat|namoci|namoct|napadat|napadávat|napadnout|napomáhat|napomoci|napomoct|nařídit|nařizovat|naštvat|natáhnout|natahovat|naučit|navrhnout|navrhovat|nechat|nechávat|nést|nosit|nosívat|nudit|nudívat|nutit|nutívat|obávat|obnášet|obnášívat|obtěžovat|odcestovat|odejet|odejít|odepírat|odepřít|odesílat|odeslat|odhodlat|odhodlávat|odcházet|odjet|odjíždět|odlétat|odlétávat|odletět|odlétnout|odletovat|odmítat|odmítnout|odnášet|odnést|odpírat|odradit|odrazovat|odskakovat|odskočit|odsoudit|odsuzovat|odtáhnout|odtahovat|odvádět|odvážet|odvážit|odvažovat|odvést|odvézt|ohodnocovat|ohodnotit|ohromit|ohromovat|okouzlit|okouzlovat|opomenout|opomíjet|opominout|oprávnit|opravňovat|oslovit|oslovovat|otrávit|otravovat|ovlivnit|ovlivňovat|pamatovat|patřit|patřívat|plánovat|plavat|plést|plout|plovat|pobavit|pobouřit|pobuřovat|pocítit|pociťovat|počínat|počít|podařit|pohánět|pohnat|pokládat|pokoušet|pokusit|polekat|položit|pomáhat|pomoci|pomoct|pomyslet|pomyslit|pomýšlet|ponechat|ponechávat|poradit|poroučet|poroučívat|poručit|posílat|poslat|pospíchat|postačit|postačovat|postřehnout|postřehovat|potěšit|potřebovat|pouštět|považovat|povést|povolit|povolovat|povšimnout|pozorovat|proběhnout|probíhat|prospět|prospívat|protáhnout|protahovat|přát|předepisovat|předepsat|předpisovat|předpokládat|představit|představovat|přehánět|přehnat|přecházet|přechodit|přejet|přejít|přejíždět|překvapit|překvapovat|přemístit|přemisťovat|přemísťovat|přemlouvat|přemluvit|přenášet|přenést|přepravit|přepravovat|přesouvat|přestat|přestávat|přesunout|přesunovat|přesvědčit|přesvědčovat|převádět|převážet|převést|převézt|přiběhnout|přibíhat|přicestovat|přicházet|přichystat|přijet|přijít|přijíždět|přikázat|přikazovat|přilétat|přilétávat|přiletět|přilétnout|přiletovat|přimět|přinutit|připadat|připadávat|připadnout|přísahat|přísahávat|přislíbit|příslušet|přistat|přistát|přistávat|přitáhnout|přitahovat|přivádět|přivážet|přivést|přivézt|přizvat|pustit|putovat|ráčit|ráčívat|radit|ranit|registrovat|rozběhnout|rozbíhat|rozčilit|rozčílit|rozčilovat|rozeběhnout|rozejít|rozesmát|rozesmávat|rozesmívat|rozhodnout|rozhodovat|rozcházet|rozjet|rozjíždět|rozmlouvat|rozmlouvávat|rozmluvit|rozmyslet|rozmyslit|rozmýšlet|rozplakat|rozplakávat|rozpoznat|rozpoznávat|rozptýlit|rozptylovat|rušit|rušívat|řítit|sejít|sestoupit|sestupovat|scházet|scházívat|sjet|sjíždět|skákat|skočit|slíbit|slibovat|slušet|slyšet|slyšívat|smět|snášet|snažit|snažívat|snést|souhlasit|spatřit|spatřovat|spěchat|splést|splétat|spouštět|spustit|stačit|stačívat|stanovit|stanovovat|stíhat|stihnout|stoupat|stoupnout|strašit|strašívat|střežit|stydět|sužovat|svádět|svázat|svazovat|svést|symbolizovat|škodit|šokovat|štvát|štvávat|táhnout|těšit|těšívat|toužit|toužívat|trápit|trápívat|troufat|troufnout|ubírat|ucítit|učit|učívat|uchvacovat|uchvátit|ukládat|uklidnit|uklidňovat|uložit|umět|umožnit|umožňovat|upoutat|upoutávat|uprchat|uprchávat|uprchnout|urazit|urážet|určit|určovat|usadit|usazovat|uslyšet|usnášet|usnést|uspokojit|uspokojovat|ustat|ustát|ustávat|uškodit|utéci|utéct|utěšit|utěšovat|utíkat|uvidět|vadit|vadívat|váhat|varovat|vejít|velet|vést|vézt|vcházet|vídat|vidět|vjet|vjíždět|vjíždívat|vkročit|vláčet|vláčit|vláčívat|vléci|vléct|vlézat|vlézt|vnikat|vniknout|vnímat|vodit|vodívat|vonět|vozit|vozívat|vrhat|vrhnout|vsouvat|vsunout|vsunovat|všímat|všimnout|vtáhnout|vtahovat|vtrhávat|vtrhnout|vtrhovat|vybavit|vybavovat|vyběhnout|vybíhat|vyčerpat|vyčerpávat|vydařit|vydat|vydávat|vyděsit|vyděšovat|vydržet|vyhánět|vyhnat|vycházet|vyjet|vyjít|vyjíždět|vykráčet|vykračovat|vykrádat|vykrást|vykročit|vykročovat|vylétat|vylétávat|vyletět|vylétnout|vyletovat|vylézat|vylézt|vymlouvat|vymluvit|vynášet|vynést|vypadat|vypadávat|vypadnout|vypálit|vypalovat|vyplácet|vyplatit|vypravit|vypravovat|vyrazit|vyrážet|vysílat|vyskakovat|vyskočit|vyslat|vyšplhat|vytáčet|vytáhnout|vytahovat|vytknout|vytočit|vytrácet|vytratit|vytrhávat|vytrhnout|vytrhovat|vytýkat|vytýkávat|vyučit|vyučovat|vyučovávat|vyvádět|vyvarovat|vyvarovávat|vyvážet|vyvést|vyvézt|vyžádat|vyžadovat|vzrušit|vzrušovat|zabloudit|zabránit|zabraňovat|začínat|začít|zahánět|zahlédnout|zahnat|zahnout|zahřát|zahřívat|zahýbat|zacházet|zajet|zajímat|zajít|zajíždět|zakázat|zakazovat|zalíbit|zamávat|zamezit|zamezovat|zamířit|zamlouvat|zamýšlet|zanášet|zanedbat|zanedbávat|zanechat|zanechávat|zanést|zapamatovat|zapamatovávat|započít|zapomenout|zapomínat|zarazit|zarážet|zasáhnout|zasahovat|zaskakovat|zaskočit|zaslechnout|zasloužit|zasluhovat|zastavit|zastavovat|zatahat|zatáhnout|zatahovat|zatěžovat|zatížit|zatoužit|zaujímat|zaujmout|zavádět|zaváhat|zavázat|zavazovat|zavést|zavítat|zavítávat|zaznamenat|zaznamenávat|zbláznit|zbožnit|zbožňovat|zdařit|zdát|zdávat|zděsit|zdráhat|zdráhávat|zdržet|zdržovat|zdvihat|zdvíhat|zdvihávat|zdvihnout|zklamat|zkoušet|zkusit|zlákat|zlobit|zlobívat|zmáhat|zmást|zmoci|zmocnit|zmocňovat|zmoct|znamenat|znechucovat|znechutit|znemožnit|znemožňovat|znepokojit|znepokojovat|zpozorovat|zranit|zraňovat|zůstat|zůstávat|zvládat|zvládnout|zvykat|zvyknout|žádat|žádávat|žrát)/ );
}

1;

__END__

# pozor: ty regexpy v promennych tady nejak nefunguji!!!
#my $verbs_with_allowed_ze_regexp = '(akceptovat|apelovat|argumentovat|bát|bavit|bolet|brát|brávat|brečet|brečívat|bručet|bručívat|být|cítit|cítívat|ctít|ctívat|čekat|čekávat|činit|činívat|číst|čítat|čítávat|dařit|dařívat|dát|dávat|deklarovat|děkovat|dělat|dělávat|demonstrovat|děsit|děsívat|diktovat|diktovávat|dít|divit|dočíst|dočítat|dočkat|dodat|dodávat|dohadovat|dohlédat|dohlédnout|dohlížet|dohodnout|dohodovat|docházet|dojímat|dojít|dojmout|dokázat|dokazovat|dokládat|dokumentovat|doléhat|doléhávat|dolehnout|doložit|domlouvat|domluvit|domnívat|donášet|donést|doplnit|doplňovat|doporučit|doporučovat|dopouštět|dopustit|dostat|dostávat|dotknout|dotýkat|doufat|dovědět|dovídat|dovolit|dovolovat|doznat|doznávat|dozvědět|dozvídat|dráždit|dráždívat|drtit|drtívat|důvěřovat|fascinovat|hádat|hlásat|hlásit|hledět|hnout|hodit|hodnotit|hrozit|hrozívat|hřát|hřávat|hýbat|hýbnout|chápat|chlubit|chlubívat|chutnat|chutnávat|chválit|chvět|chybět|chybit|chybívat|chybovat|chystat|ignorovat|informovat|interpretovat|jásat|jásávat|jevit|jímat|jímávat|jmout|kázat|klamat|klamávat|kombinovat|konstatovat|kontrolovat|konzultovat|korespondovat|koukat|kouknout|křičet|křičívat|křiknout|léhat|léhávat|lekat|lekávat|leknout|ležet|lhát|líbit|libovat|líčit|litovat|mást|míchat|míchávat|mínit|mínívat|mít|mívat|motivovat|mrzet|mučit|mučívat|mýlit|myslet|myslit|nabádat|nabídnout|nabízet|nadat|nadávat|nadchnout|nahlásit|nahlašovat|nahlédnout|nahlížet|nacházet|najít|nakázat|nakazovat|naladit|nalaďovat|naléhat|nalehnout|namítat|namítnout|namlouvat|namluvit|napadat|napadávat|napadnout|naplánovat|napovědět|napovídat|napsat|nařídit|naříkat|naříkávat|nařizovat|nařknout|nasvědčit|nasvědčovat|naštvat|naučit|navrhnout|navrhovat|naznačit|naznačovat|nechat|nechávat|nenávidět|nudit|nudívat|obávat|obdivovat|objasnit|objasňovat|objevit|objevovat|obtěžovat|obvinit|obviňovat|obžalovat|obžalovávat|ocenit|oceňovat|očekávat|odčíst|odčítat|oddechnout|oddychnout|oddýchnout|odečíst|odečítat|odepisovat|odepsat|odhadnout|odhadovat|odhalit|odhalovat|odhlasovat|odhodlat|odhodlávat|odkrýt|odkrývat|odnášet|odnést|odpisovat|odpouštět|odpovědět|odpovídat|odpustit|odradit|odrazovat|odsouhlasit|odůvodnit|odůvodňovat|odvětit|odvodit|odvozovat|ohlásit|ohlašovat|ohodnocovat|ohodnotit|ohradit|ohrazovat|ohromit|ohromovat|okouzlit|okouzlovat|omlouvat|omluvit|opakovat|opisovat|opomenout|opomíjet|opominout|opsat|oslavit|oslavovat|oslovit|oslovovat|osvědčit|osvědčovat|osvětlit|osvětlovat|osvojit|osvojovat|otisknout|otiskovat|otrávit|otravovat|ověřit|ověřovat|ovlivnit|ovlivňovat|oznámit|oznamovat|pamatovat|patřit|patřívat|pět|plánovat|platit|platívat|plést|plynout|pobavit|pobouřit|pobuřovat|pocítit|pociťovat|počítat|podařit|podcenit|podceňovat|podepisovat|podepsat|podezírat|podezřívat|podívat|podivit|podivovat|podkládat|podložit|podněcovat|podnítit|podotknout|podotýkat|podpisovat|podržet|podtrhat|podtrhávat|podtrhnout|podtrhovat|pohádat|pohledět|pohlédnout|pohlížet|pohrozit|pochlubit|pochopit|pochválit|pochvalovat|pochvalovávat|pochybovat|pokládat|polekat|polemizovat|položit|pomíjet|pominout|pomyslet|pomyslit|pomýšlet|popírat|popisovat|popovídat|popřít|popsat|poradit|poroučet|poroučívat|porozumět|poručit|poslechnout|poslouchat|posoudit|postavit|postesknout|postěžovat|postihnout|postihovat|postřehnout|postřehovat|postýskat|postýskávat|posuzovat|potěšit|potvrdit|potvrzovat|poučit|poučovat|pouštět|poutat|poutávat|považovat|povědět|povídat|povolit|povolovat|povšimnout|povzbudit|povzbuzovat|povzdechnout|povzdechovat|povzdychat|povzdychávat|povzdychnout|povzdychovat|poznamenat|poznamenávat|poznat|poznávat|pozorovat|pramenit|praskat|praskávat|prasknout|pravit|proběhnout|probíhat|probírat|probrat|proházet|prohazovat|prohlásit|prohlašovat|prohlédnout|prohlížet|prohodit|procházet|projevit|projevovat|projít|prokázat|prokazovat|promíjet|prominout|pronášet|pronést|propagovat|prosadit|prosazovat|proslavit|proslavovat|prospět|prospívat|prostudovat|prověřit|prověřovat|provokovat|prozradit|prozrazovat|přecenit|přeceňovat|přečíst|předepisovat|předepsat|předestřít|přednášet|přednést|předpisovat|předpokládat|předpovědět|předpovídat|představit|představovat|předstírat|předurčit|předurčovat|předvídat|přehánět|přehlédnout|přehlížet|přehnat|přehodnocovat|přehodnotit|přecházet|přechodit|přejít|překvapit|překvapovat|přemáhat|přemítat|přemítávat|přemlouvat|přemluvit|přemoci|přemoct|přemýšlet|přesvědčit|přesvědčovat|přičíst|přičítat|přičítávat|přiházet|přihodit|přicházet|přichystat|přijímat|přijít|přijmout|přikázat|přikazovat|připadat|připadávat|připadnout|připočíst|připočítat|připočítávat|připomenout|připomínat|připouštět|připustit|přísahat|přísahávat|přislíbit|přistihnout|přistihovat|přít|přitáhnout|přitahovat|přivítat|přiznat|přiznávat|psát|psávat|publikovat|působit|pustit|pyšnit|pyšnívat|radit|radovat|ranit|referovat|reflektovat|registrovat|respektovat|riskovat|rozbírat|rozčilit|rozčílit|rozčilovat|rozebírat|rozebrat|rozesmát|rozesmávat|rozesmívat|rozeznat|rozeznávat|rozhodnout|rozhodovat|rozlišit|rozlišovat|rozmlouvat|rozmlouvávat|rozmluvit|rozmyslet|rozmyslit|rozmýšlet|rozplakat|rozplakávat|rozplynout|rozplývat|rozpoznat|rozpoznávat|rozptýlit|rozptylovat|rozumět|rušit|rušívat|rýsovat|řešit|řešívat|říci|říct|říkat|říkávat|řvát|sázet|sbírat|sčíst|sčítat|sčítávat|sdělit|sdělovat|sebrat|sečíst|sečítat|sečítávat|sedat|sedávat|sednout|sejít|sepisovat|sepsat|setkat|setkávat|sežrat|shledat|shledávat|shodnout|shodovat|scházet|scházívat|schválit|schvalovat|signalizovat|sjednat|sjednávat|skrýt|skrývat|slíbit|slibovat|slyšet|slyšívat|smát|smávat|snášet|snést|snít|soudit|souhlasit|spatřit|spatřovat|specifikovat|spekulovat|spisovat|splést|splétat|spočítat|spoléhat|spolehnout|spolknout|spolykat|spouštět|spravit|spravovat|spustit|stačit|stačívat|stanovit|stanovovat|stát|stávat|stavět|stesknout|stěžovat|strašit|strašívat|stydět|stýskat|stýskávat|stýsknout|sužovat|svázat|svazovat|svěřit|svěřovat|symbolizovat|šeptat|šeptávat|šeptnout|šířit|šokovat|štvát|štvávat|táhnout|tajit|telefonovat|těšit|těšívat|tlouci|tlouct|tloukávat|tlumočit|tlumočívat|tolerovat|trápit|trápívat|troufat|troufnout|třást|tušit|tušívat|tvrdit|tvrdívat|týkat|ublížit|ubližovat|ucítit|učit|učívat|udat|udát|udávat|uhádnout|uhadovat|uhodnout|ucházet|uchvacovat|uchvátit|ujistit|ujišťovat|ujít|ukázat|ukazovat|ukládat|uklidnit|uklidňovat|uložit|umožnit|umožňovat|unášet|unést|upéci|upéct|upírat|upoutat|upoutávat|upozornit|upozorňovat|upřesnit|upřesňovat|upřít|urazit|urážet|určit|určovat|usadit|usazovat|uslyšet|usnášet|usnést|usoudit|uspokojit|uspokojovat|ustálit|ustalovat|ustanovit|ustanovovat|ustát|usuzovat|usvědčit|usvědčovat|ušklebovat|ušklíbat|ušklíbnout|ušklibovat|uškodit|utajit|utajovat|utěšit|utěšovat|uvádět|uvážit|uvažovat|uvažovávat|uvědomit|uvědomovat|uveřejnit|uveřejňovat|uvěřit|uvést|uvidět|uvítat|uznat|uznávat|vadit|vadívat|varovat|vážit|vděčit|vědět|vejít|velet|věřit|věřívat|vést|vcházet|vídat|vidět|vinit|vinívat|vítat|vnímat|vnucovat|vnutit|volat|volávat|vonět|vsadit|vsázet|všímat|všimnout|vybavit|vybavovat|vybídnout|vybízet|vycítit|vyciťovat|vyčerpat|vyčerpávat|vyčíst|vyčítat|vydařit|vydechnout|vydechovat|vyděsit|vyděšovat|vydychnout|vydýchnout|vydychovat|vyhlásit|vyhlašovat|vyhodnocovat|vyhodnotit|vyhradit|vyhrazovat|vyhrkat|vyhrkávat|vyhrknout|vyhrkovat|vyhrožovat|vycházet|vychutnat|vychutnávat|vyjádřit|vyjadřovat|vyjasnit|vyjasňovat|vyjednat|vyjednávat|vyjít|vykládat|vykřiknout|vykřikovat|vylézat|vylézt|vyloučit|vyložit|vylučovat|vymáhat|vymlouvat|vymluvit|vymoci|vymoct|vymyslet|vymyslit|vymýšlet|vynucovat|vynutit|vypadat|vypadávat|vypadnout|vypátrat|vypít|vyplácet|vyplatit|vyplynout|vyplývat|vypočíst|vypočítat|vypočítávat|vypovědět|vypovídat|vyprávět|vypravit|vypravovat|vyprovokovat|vyprovokovávat|vyrozumět|vyrozumívat|vyřídit|vyřizovat|vyslechnout|vyslovit|vyslovovat|vyslýchat|vyslyšet|vystihnout|vystihovat|vysvětlit|vysvětlovat|vytáčet|vytáhnout|vytahovat|vytisknout|vytknout|vytočit|vytrhávat|vytrhnout|vytrhovat|vytýkat|vytýkávat|vyvádět|vyvést|vyvodit|vyvozovat|vyvracet|vyvrátit|vyzářit|vyzařovat|vyznat|vyznávat|vyzvat|vyzývat|vyžádat|vyžadovat|vzít|vzkázat|vzkazovat|vzpomenout|vzpomínat|vzrušit|vzrušovat|zahlédnout|zahřát|zahřívat|zachycovat|zachytávat|zachytit|zachytnout|zajímat|zajistit|zajišťovat|zakrýt|zakrývat|zalíbit|zamávat|zamlouvat|zamluvit|zamumlat|zamyslet|zamyslit|zamýšlet|zanedbat|zanedbávat|zanechat|zanechávat|zapamatovat|zapamatovávat|zapírat|zapomenout|zapomínat|zapřít|zarazit|zarážet|zaregistrovat|zaručit|zaručovat|zařvat|zasadit|zasáhnout|zasahovat|zasazovat|zaskakovat|zaskočit|zaslechnout|zasmát|zastírat|zastřít|zašeptat|zatelefonovat|zatěžovat|zatížit|zaujímat|zaujmout|zavázat|zavazovat|závidět|závidívat|zavolat|zavrhnout|zavrhovat|zaznamenat|zaznamenávat|zazpívat|zažít|zažívat|zbláznit|zbožnit|zbožňovat|zdařit|zdát|zdávat|zděsit|zdůraznit|zdůrazňovat|zdůvodnit|zdůvodňovat|zírat|zjevit|zjevovat|zjevovávat|zjistit|zjišťovat|zklamat|zlobit|zlobívat|zmáhat|zmást|zmínit|zmiňovat|zmoci|zmoct|značit|značívat|znamenat|znechucovat|znechutit|znemožnit|znemožňovat|znepokojit|znepokojovat|zopakovat|zpívat|zpívávat|zpochybnit|zpochybňovat|zpozorovat|způsobit|způsobovat|zradit|zranit|zraňovat|zrázet|zrazovat|zrážet|zuřit|zuřívat|zůstat|zůstávat|zvážit|zvažovat|zveřejnit|zveřejňovat|zvolat|zvykat|zvyknout|žádat|žádávat|žalovat|žalovávat|žárlit|žárlívat|žasnout|žrát)';

#sub _Verb_with_allowed_ze {
#  my $verb = shift;
#  return ($verb=~/$verbs_with_allowed_ze_regexp/);
#}

#my $verbs_with_allowed_2_regexp = '(bát|být|cenit|čerpat|dbát|děsit|děsívat|dobýt|dobývat|docílit|docilovat|dočkat|dodat|dodávat|docházet|dojít|domáhat|domoci|dopouštět|dopracovat|dopracovávat|dopřát|dopřávat|dopustit|dosáhnout|dosahovat|dospět|dospívat|dostat|dostávat|dostihnout|dostihovat|dotknout|dotýkat|dovolat|dovolávat|dovolit|dovolovat|doznat|doznávat|dožadovat|dožít|dožívat|držet|hledět|hrozit|hrozívat|chápat|chopit|chránit|chybit|chybovat|chytat|chytit|chytnout|lekat|lekávat|leknout|litovat|míjet|minout|nabýt|nabývat|načerpat|nadat|nadávat|nadechnout|nadechovat|nadělat|nadělávat|nadýchnout|nadychovat|najíst|nakoupit|nakupovat|nalévat|nalít|namlouvat|namluvit|nanášet|nanést|nanosit|napadat|napadávat|napadnout|napít|nasbírat|následovat|nechat|nechávat|obávat|odvážit|odvažovat|ochutnat|ochutnávat|otázat|pobírat|pobrat|podržet|polekat|polknout|polykat|polykávat|popíjet|popít|popřát|popřávat|postrádat|pouštět|použít|používat|považovat|povšimnout|požít|požívat|prosit|přát|přebírat|přebírávat|přebrat|převzít|přibýt|přibývat|přidat|přidávat|přidržet|přidržovat|přilévat|přilít|připadat|připadávat|připadnout|ptát|ptávat|pustit|sežrat|střežit|tázat|týkat|ubírat|ubrat|ubýt|ubývat|účastnit|uchránit|ujímat|ujmout|uposlechnout|ušetřit|užít|užívat|varovat|vážit|všímat|všimnout|vyčkat|vyčkávat|vyděsit|vyděšovat|vyptat|vyptávat|vystříhat|využít|využívat|vyvarovat|vyvarovávat|vyžádat|vyžadovat|vzdát|vzdávat|vzpomenout|vzpomínat|zachycovat|zachytávat|zachytit|zachytnout|zanechat|zanechávat|zasloužit|zasluhovat|zastat|zastávat|zbavit|zbavovat|zbýt|zděsit|zdržet|zdržovat|zeptat|zmocnit|zmocňovat|zneužít|zneužívat|zprostit|zprošťovat|zřeknout|zříci|zříkat|zúčastnit|zúčastňovat)';

#sub _Verb_with_allowed_2 {
#  my $verb = shift;
#  return ($verb=~/$verbs_with_allowed_2_regexp/);
#}


=over

=item Treex::Block::T2T::EN2CS::FixTransferChoices

Manual rules for fixing the formeme and lemma choices,
which are otherwise systematically wrong and are reasonably
frequent.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
