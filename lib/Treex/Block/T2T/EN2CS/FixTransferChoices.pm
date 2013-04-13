package Treex::Block::T2T::EN2CS::FixTransferChoices;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::CS;

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
    my ($cs_parent) = $cs_tnode->get_eparents( { or_topological => 1 } );

    return 'který#P' if $cs_tlemma eq 'tento' && $cs_parent->is_relclause_head;

    my $en_tnode = $cs_tnode->src_tnode or return;
    my $en_tlemma = $en_tnode->t_lemma;

    # oprava reflexiv (!!! lepe opravit uz ve slovniku)
    return "${cs_tlemma}_se#V" if $en_tlemma =~ /become|learn|happen/ && $cs_tlemma =~ /t$/;

    if ( $cs_tlemma =~ /(.+)_s[ie]$/ and $cs_tnode->is_passive ) {
        return "$1#V";
    }

    if ( $cs_tlemma eq 'být' ) {    # to be afraid --> *mit* strach
        my ($strach_node) = grep { $_->t_lemma eq 'strach' } $cs_tnode->get_children;
        if ( $strach_node and $strach_node->src_tnode and $strach_node->src_tnode->t_lemma eq 'afraid' ) {
            return 'mít#V';
        }
    }

    # this is probably due to wrong tagging/lemmatization in CzEng
    return 'peníze#N' if $cs_tlemma eq 'peníz';

    return;
}

sub fix_formeme {
    my ($cs_tnode)  = @_;
    my $cs_tlemma   = $cs_tnode->t_lemma;
    my $cs_formeme  = $cs_tnode->formeme;
    my ($cs_parent) = $cs_tnode->get_eparents( { or_topological => 1 } );
    my $cs_parent_tlemma  = $cs_parent->t_lemma               || '#root';
    my $cs_parent_formeme = $cs_parent->formeme               || '#root';
    my $cs_pos            = $cs_tnode->get_attr('mlayer_pos') || '';
    my $cs_tree_parent    = $cs_tnode->get_parent();

    my $en_tnode = $cs_tnode->src_tnode or return;
    my $en_formeme = $en_tnode->formeme;
    my ($en_parent) = $en_tnode->get_eparents( { or_topological => 1 } );

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
                or not Treex::Tool::Lexicon::CS::get_poss_adj($cs_tlemma)
                or ( $cs_tnode->gram_number || '' ) eq 'pl'
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

    if ( $cs_formeme eq 'adj:attr' && $cs_pos eq 'N' && !Treex::Tool::Lexicon::CS::number_for($cs_tlemma)) {
        return 'n:attr' if $cs_tnode->is_name_of_person or $cs_parent->is_name_of_person;
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
        $cs_tnode->set_gram_sempos('adj.denot');
        $cs_tnode->set_functor('RSTR');
        return 'adj:attr';
    }

    # !!! tohle zahodit, az se pretrenuje maxent (doted nemohl videt spojku 'when')
    return 'v:když+fin' if ( $en_formeme =~ /when\+/ and $cs_formeme =~ /fin/ );

    return 'adj:attr' if $cs_formeme eq 'n:2' && $cs_tlemma =~ /^ten(to)?$/
            && $cs_parent_formeme =~ /^n/ && $cs_tnode->precedes($cs_parent);

    return 'n:1' if $cs_formeme eq 'n:5';    # there are almost no vocatives in newspapers, unlike in CzEng

    return 'adv:' if $cs_pos eq 'D' and $cs_formeme =~ /n:(.+)\+/ and $1 ne "než";    # 'nez' is a conjunction indeed

    # 'zpusob jak ...'
    if ( $cs_formeme eq 'v:inf' and $en_formeme eq 'v:to+inf' and $cs_parent_tlemma eq 'způsob' ) {
        return 'v:jak+inf';
    }

    return;
}

my $INF = 'bát|bavit|běhat|běhávat|běžet|bolet|bránit|být|cestovat|cítit|cítívat|činit|
činívat|dařit|dařívat|dát|dávat|dělat|dělávat|děsit|děsívat|diktovat|diktovávat|
dlužit|doběhnout|dobíhat|dobývat|docházet|dojet|dojímat|dojít|dojíždět|dojmout|
dokázat|dokazovat|donutit|doporučit|doporučovat|dopravit|dopravovat|doprovázet|
doprovodit|dopřát|dopřávat|dostat|dostávat|dostavit|dostavovat|dotáhnout|
dotahovat|dotknout|dotýkat|dovádět|dovážet|dovést|dovézt|dovolit|dovolovat|drát|
drávat|dráždit|dráždívat|drtit|drtívat|fascinovat|hledět|hnát|hnout|hodit|hodlat
|hodnotit|honit|hrnout|hřát|hřávat|hýbat|hýbnout|chodit|chodívat|chránit|chtít|
chutnat|chutnávat|chybět|chybívat|chystat|jet|jezdit|jezdívat|jímat|jímávat|jít|
jmout|kázat|klamat|klamávat|koukat|kouknout|kráčet|lákat|lekat|lekávat|létat|
letět|líbit|litovat|mást|míchat|míchávat|mínit|mínívat|mít|mívat|mizet|moci|moct
|motivovat|mrzet|mučit|mučívat|muset|musit|nabídnout|nabízet|nadchnout|nacházet|
najít|nakázat|nakazovat|naladit|nalaďovat|náležet|namáhat|
namoci|namoct|napadat|napadávat|napadnout|napomáhat|napomoci|napomoct|nařídit|
nařizovat|naštvat|natáhnout|natahovat|naučit|navrhnout|navrhovat|nechat|nechávat
|nést|nosit|nosívat|nudit|nudívat|nutit|nutívat|obávat|obnášet|obnášívat|
obtěžovat|odcestovat|odejet|odejít|odepírat|odepřít|odesílat|odeslat|odhodlat|
odhodlávat|odcházet|odjet|odjíždět|odlétat|odlétávat|odletět|odlétnout|odletovat
|odmítat|odmítnout|odnášet|odnést|odpírat|odradit|odrazovat|odskakovat|odskočit|
odsoudit|odsuzovat|odtáhnout|odtahovat|odvádět|odvážet|odvážit|odvažovat|odvést|
odvézt|ohodnocovat|ohodnotit|ohromit|ohromovat|okouzlit|okouzlovat|opomenout|
opomíjet|opominout|oprávnit|opravňovat|oslovit|oslovovat|otrávit|otravovat|
ovlivnit|ovlivňovat|pamatovat|patřit|patřívat|plánovat|plavat|plést|plout|plovat
|pobavit|pobouřit|pobuřovat|pocítit|pociťovat|počínat|počít|podařit|pohánět|
pohnat|pokládat|pokoušet|pokusit|polekat|položit|pomáhat|pomoci|pomoct|pomyslet|
pomyslit|pomýšlet|ponechat|ponechávat|poradit|poroučet|poroučívat|poručit|
posílat|poslat|pospíchat|postačit|postačovat|postřehnout|postřehovat|potěšit|potřebovat|
pouštět|považovat|povést|povolit|povolovat|povšimnout|pozorovat|proběhnout|
probíhat|prospět|prospívat|protáhnout|protahovat|přát|předepisovat|předepsat|
předpisovat|předpokládat|představit|představovat|přehánět|přehnat|přecházet|
přechodit|přejet|přejít|přejíždět|překvapit|překvapovat|přemístit|přemisťovat|
přemísťovat|přemlouvat|přemluvit|přenášet|přenést|přepravit|přepravovat|
přesouvat|přestat|přestávat|přesunout|přesunovat|přesvědčit|přesvědčovat|
převádět|převážet|převést|převézt|přiběhnout|přibíhat|přicestovat|přicházet|
přichystat|přijet|přijít|přijíždět|přikázat|přikazovat|přilétat|přilétávat|
přiletět|přilétnout|přiletovat|přimět|přinutit|připadat|připadávat|připadnout|
přísahat|přísahávat|přislíbit|příslušet|přistat|přistát|přistávat|přitáhnout|
přitahovat|přivádět|přivážet|přivést|přivézt|přizvat|pustit|putovat|ráčit|
ráčívat|radit|ranit|registrovat|rozběhnout|rozbíhat|rozčilit|rozčílit|rozčilovat
|rozeběhnout|rozejít|rozesmát|rozesmávat|rozesmívat|rozhodnout|rozhodovat|rozcházet|rozjet|rozjíždět|rozmlouvat|
rozmlouvávat|rozmluvit|rozmyslet|rozmyslit|rozmýšlet|rozplakat|rozplakávat|
rozpoznat|rozpoznávat|rozptýlit|rozptylovat|rušit|rušívat|řítit|sejít|sestoupit|
sestupovat|scházet|scházívat|sjet|sjíždět|skákat|skočit|slíbit|slibovat|slušet|
slyšet|slyšívat|smět|snášet|snažit|snažívat|snést|souhlasit|spatřit|spatřovat|
spěchat|splést|splétat|spouštět|spustit|stačit|stačívat|stanovit|stanovovat|
stíhat|stihnout|stoupat|stoupnout|strašit|strašívat|střežit|stydět|sužovat|
svádět|svázat|svazovat|svést|symbolizovat|škodit|šokovat|štvát|štvávat|táhnout|
těšit|těšívat|toužit|toužívat|trápit|trápívat|troufat|troufnout|ubírat|ucítit|
učit|učívat|uchvacovat|uchvátit|ukládat|uklidnit|uklidňovat|uložit|umět|umožnit|
umožňovat|upoutat|upoutávat|uprchat|uprchávat|uprchnout|urazit|urážet|určit|
určovat|usadit|usazovat|uslyšet|usnášet|usnést|uspokojit|uspokojovat|ustat|ustát
|ustávat|uškodit|utéci|utéct|utěšit|utěšovat|utíkat|uvidět|vadit|vadívat|váhat|
varovat|vejít|velet|vést|vézt|vcházet|vídat|vidět|vjet|vjíždět|vjíždívat|vkročit|vláčet|vláčit
|vláčívat|vléci|vléct|vlézat|vlézt|vnikat|vniknout|vnímat|vodit|vodívat|vonět|
vozit|vozívat|vrhat|vrhnout|vsouvat|vsunout|vsunovat|všímat|všimnout|vtáhnout|
vtahovat|vtrhávat|vtrhnout|vtrhovat|vybavit|vybavovat|vyběhnout|vybíhat|vyčerpat
|vyčerpávat|vydařit|vydat|vydávat|vyděsit|vyděšovat|vydržet|vyhánět|vyhnat|
vycházet|vyjet|vyjít|vyjíždět|vykráčet|vykračovat|vykrádat|vykrást|vykročit|
vykročovat|vylétat|vylétávat|vyletět|vylétnout|vyletovat|vylézat|vylézt|
vymlouvat|vymluvit|vynášet|vynést|vypadat|vypadávat|vypadnout|vypálit|vypalovat|
vyplácet|vyplatit|vypravit|vypravovat|vyrazit|vyrážet|vysílat|vyskakovat|
vyskočit|vyslat|vyšplhat|vytáčet|vytáhnout|vytahovat|vytknout|vytočit|vytrácet|
vytratit|vytrhávat|vytrhnout|vytrhovat|vytýkat|vytýkávat|vyučit|vyučovat|
vyučovávat|vyvádět|vyvarovat|vyvarovávat|vyvážet|vyvést|vyvézt|vyžádat|vyžadovat
|vzrušit|vzrušovat|zabloudit|zabránit|zabraňovat|začínat|začít|zahánět|
zahlédnout|zahnat|zahnout|zahřát|zahřívat|zahýbat|zacházet|zajet|zajímat|zajít|zajíždět|zakázat|zakazovat|
zalíbit|zamávat|zamezit|zamezovat|zamířit|zamlouvat|zamýšlet|zanášet|zanedbat|
zanedbávat|zanechat|zanechávat|zanést|zapamatovat|zapamatovávat|započít|
zapomenout|zapomínat|zarazit|zarážet|zasáhnout|zasahovat|zaskakovat|zaskočit|
zaslechnout|zasloužit|zasluhovat|zastavit|zastavovat|zatahat|zatáhnout|zatahovat
|zatěžovat|zatížit|zatoužit|zaujímat|zaujmout|zavádět|zaváhat|zavázat|zavazovat|
zavést|zavítat|zavítávat|zaznamenat|zaznamenávat|zbláznit|zbožnit|zbožňovat|
zdařit|zdát|zdávat|zděsit|zdráhat|zdráhávat|zdržet|zdržovat|zdvihat|zdvíhat|
zdvihávat|zdvihnout|zklamat|zkoušet|zkusit|zlákat|zlobit|zlobívat|zmáhat|zmást|
zmoci|zmocnit|zmocňovat|zmoct|znamenat|znechucovat|znechutit|znemožnit|
znemožňovat|znepokojit|znepokojovat|zpozorovat|zranit|zraňovat|zůstat|zůstávat|
zvládat|zvládnout|zvykat|zvyknout|žádat|žádávat|žrát';
$INF =~ s/\n//g;
my %CAN_HAVE_INF_CHILD = map {$_=>1} split /\|/, $INF;

sub _Verb_with_allowed_inf {
    my $verb = shift;
    $verb =~ s/_s[ei]//;
    return $CAN_HAVE_INF_CHILD{$verb};
}

1;

__END__

=over

=item Treex::Block::T2T::EN2CS::FixTransferChoices

Manual rules for fixing the formeme and lemma choices,
which are otherwise systematically wrong and are reasonably
frequent.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
