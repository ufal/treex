package Treex::Tool::Lexicon::CS::Reflexivity;

use strict;
use warnings;
use utf8;

my $tantum_si_regexp = "libovat|oblibovat|oblíbit|postesknout|postýskat|
postýskávat|postěžovat|povšimnout|stěžovat|stýskat|stesknout|stýsknout|
stýskávat|šplhnout|troufat|troufnout|všímat|všimnout|zapamatovávat|zapamatovat|
lehnout|odpočnout|odpočinout|pochutnat|pochutnávat|sednout|uvědomit|uvědomovat|
vzpomenout|vzpomínat|zasloužit|dobírat|hovět|lebedit|osvojit|pamatovat|pospíšit|
prohlížet|prohlédnout|popovídat";

my $tantum_se_regexp = "bát|blížit|dařit|dařívat|dít|dívat|divit|dohadovat|
dochovávat|dochovat|domáhat|domoci|domnívat|dostavovat|dostavit|dotýkat|
dotknout|dovolávat|dovolat|dozvídat|dovídat|dozvědět|dovědět|dožadovat|
hemžit|hroutit|chlubit|chlubívat|lepšit|lesknout|líbit|linout|loučit|loučívat|
modlit|modlívat|najíst|napít|narodit|naskytat|naskýtat|naskytovat|naskytnout|
obávat|ocitat|ocítat|ocitnout|octnout|odhodlávat|odhodlat|odmlčovat|odmlčet|
odvažovat|odvážit|ohlížet|ohlédnout|ohrazovat|ohradit|otázat|ozývat|ozvat|
podařit|podílet|podívat|podivovat|podivit|podobat|pohádat|pochlubit|poprat|
postarat|povést|přiházet|přihodit|přít|ptát|ptávat|pyšnit|pyšnívat|radovat|
rozhlížet|rozhlédnout|rozpadávat|rozpadat|rozpadnout|rozpadat|rozplývat|
rozplynout|rozrůstat|rozrůst|řítit|setkávat|setkat|shodovat|shodnout|smát|
smávat|snažit|snažívat|specializovat|spiknout|spokojovat|spokojit|starat|
stávat|stydět|stýkat|stýkávat|tázat|toulat|toulávat|tvářit|týkat|účastnit|
udát|ucházet|uchylovat|uchýlit|usmívat|usmát|usnášet|usnést|ušklebovat|
ušklibovat|ušklíbat|ušklíbnout|utkávat|vadit|vadívat|vloupávat|vlupovat|
vloupat|vydařit|vyhýbat|vyhnout|vyhrkat|vyptávat|vyptat|vyskytovat|vyskytnout|
vyspat|vystříhat|vyvarovávat|vyvarovat|vzpamatovávat|vzpamatovat|zabývat|
zadívat|zahledět|zalíbit|zamilovat|zamračit|zasmát|zdařit|zdát|zdávat|zdráhat|
zdráhávat|zeptat|zříkat|zříci|zřeknout|zřítit|zúčastňovat|zúčastnit|plížit|
připlížit|hrbit|shrbit|krčit|klikatit|vynořit|skrčit|rouhat|potulovat|
řítit|rozednívat";

sub fix_reflexivity {
    my $lemma = shift;

    if ( $lemma =~ /^($tantum_si_regexp)$/sxm ) {
        return $lemma . "_si";
    }
    elsif ( $lemma =~ /^($tantum_se_regexp)$/sxm ) {
        return $lemma . "_se";
    }
    else {
        return $lemma;
    }
}

# A list of all lemmas which may possibly be a reflexive tantum (in a given sense)
my $possible_tantums =
    "adaptovat_se|aktivizovat_se|aktivovat_se|angažovat_se|balit_se|balívat_se|batolit_se|bát_se|
bavit_se|belhat_se|bít_se|blížící_se|blížit_se|blýskat_se|blýsknout_se|bortit_se|bouřit_se|
bránit_se|brát_se|brát_si|brávat_se|brávat_si|brodit_se|brousit_si|budit_se|budující_si|
čekat_se|cenit_si|chápat_se|chlubit_se|chlubívat_se|chopit_se|chovat_se|chránit_se|chtít_se|
chvástat_se|chvět_se|chýlit_se|chystající_se|chystat_se|chystávat_se|chytit_se|chytnout_se|
činící_si|činit_se|činit_si|cítit_se|cítívat_se|cpát_se|cpávat_se|dařit_se|dařívat_se|
datovat_se|dát_se|dát_si|dávat_se|dávat_si|děkovat_se|dělat_se|dělat_si|dělávat_se|
dělávat_si|dělit_se|děsívat_se|diferencovat_se|distancovat_se|dít_se|dívat_se|divit_se|
dobírat_si|dobrání_se|dobrat_se|dobývat_se|dochovat_se|dočíst_se|dočítat_se|dočkat_se|
dohadovat_se|dohodnout_se|dohodnutí_se|dohrát_si|dojmout_se|domáhat_se|domlouvat_se|
domluvit_se|domnívat_se|domoci_se|domýšlet_se|donést_se|dopisovat_si|doplatit_se|doplazit_se|
doplňovat_se|dopočítat_se|dopouštět_se|dopracovat_se|dopřát_si|dopravit_se|dopustit_se|
dorozumět_se|dorozumívat_se|došlápnout_si|doslechnout_se|dostat_se|dostávat_se|dostavit_se|
dostavovat_se|dotáhnout_se|dotázat_se|dotazovat_se|dotazující_se|dotknout_se|dotýkající_se|
dotýkat_se|dovědět_se|dovídat_se|dovolat_se|dovolávat_se|dovolit_se|dovolit_si|dovolovat_se|
dovolovat_si|dovršit_se|dožadovat_se|dožít_se|dožívat_se|doznat_se|dozvědět_se|dozvídat_se|
drát_se|drávat_se|dřít_se|družit_se|držet_se|dusit_se|dusívat_se|dušovat_se|etablovat_se|
formovat_se|habilitovat_se|hádat_se|hájit_se|hasívat_si|hemžit_se|hlásící_se|hlásit_se|
hledět_si|hloubit_se|hnát_se|hněvat_se|hnout_se|hodit_se|hojit_se|holedbat_se|honit_se|
honosit_se|houfovat_se|houpat_se|houpávat_se|hovět_si|hrabat_se|hrát_si|hřávat_se|hrávat_si|
hrnout_se|hromadit_se|hroutit_se|hrozit_se|hrozívat_se|humanizující_se|hýbat_se|
idealizovat_si|identifikovat_se|informovat_se|inspirovat_se|integrovat_se|izolovat_se|
jednat_se|jednávat_se|jevit_se|ježit_se|jistý_si|jmenovat_se|jmout_se|kát_se|kazívat_se|
klamávat_se|klást_se|klenout_se|klepávat_se|klikatit_se|klouzat_se|klubat_se|kochat_se|
kočkovat_se|kombinovat_se|komplikovat_se|konat_se|koncentrovat_se|končit_se|koukat_se|
koupat_se|koupávat_se|kouřit_se|kousat_se|krást_se|krátívat_se|krčit_se|krčívat_se|
kroutívat_se|krýt_se|kumulovat_se|kutálet_se|kvalifikovat_se|kývat_se|lámat_se|lámat_si|
lehat_si|lehnout_si|lekávat_se|lepívat_se|lepšit_se|lesknout_se|líbat_se|líbit_se|
libovat_si|linout_se|lišící_se|lišit_se|lišívat_se|lít_se|loučit_se|loučívat_se|
malovávat_se|mást_se|mazlit_se|měnit_se|měnívat_se|měřívat_se|míchávat_se|míhat_se|
mihnout_se|míjet_se|milovat_se|minout_se|mísit_se|mísívat_se|mít_se|mívat_se|mlátívat_se|
mlít_se|množit_se|množívat_se|moci_si|modlit_se|modlívat_se|montovat_se|motat_se|mračit_se|
mrknout_se|mrzet_se|mstít_se|mučívat_se|mýlit_se|mýlit_si|myslet_si|myslit_si|nabalovat_se|
nabídnout_si|nabízet_se|nabourat_se|nabrat_se|nacházející_se|nacházet_se|nachmelit_se|
nadát_se|nadchnout_se|nadýchat_se|najíst_se|najít_se|nakazit_se|naklánět_se|naklonit_se|
naklonit_si|nalepit_se|nalézat_se|nalít_se|nalodit_se|namáhat_se|namluvit_si|namočit_se|
napít_se|naplnit_se|naplňovat_se|napojit_se|napravit_se|narazit_se|narazit_si|narodit_se|
naroubovat_se|narovnat_se|narušit_se|nasbírat_se|naskýtat_se|naskytnout_se|nastěhovat_se|
naštvat_se|natáhnout_se|natočit_se|naturalizovat_se|naučit_se|navečeřet_se|navracívat_se|
navštěvovat_se|nažrat_se|nazývat_se|nechat_se|nechat_si|nechávat_si|nést_se|nosit_se|
nudit_se|nudívat_se|obávající_se|obávat_se|obdivovat_se|obejít_se|obejmout_se|obhlédnout_si|
objevit_se|objevovat_se|oblékat_se|oblíbit_si|obnovit_se|obnovovat_se|obohatit_se|obořit_se|
obracet_se|obrátit_se|obrážet_se|obrodit_se|obtěžovat_se|ochladit_se|očistit_se|ocitat_se|
ocitnout_se|octnout_se|odbýt_se|odbýt_si|odbývat_se|odchylovat_se|odcizit_se|odcizit_si|
oddálit_se|oddat_se|oddechnout_si|oddělit_se|oddělovat_se|oddychnout_si|odebrat_se|
odehrát_se|odehrávat_se|odevzdat_se|odhlašování_se|odhodlat_se|odhodlávat_se|odklonit_se|
odkrýt_se|odlepit_se|odlišit_se|odlišovat_se|odměnit_se|odmlčet_se|odmyslit_si|odnaučit_se|
odnést_si|odplížit_se|odpočinout_si|odpoutat_se|odpovídat_se|odpustit_si|odpykat_si|
odpykávat_si|odrážet_se|odrazit_se|odreagovat_se|odříci_si|odříkat_se|odsedět_si|
odsednout_si|odskakovat_si|odskočit_si|odsloužit_si|odstěhovat_se|odštěpit_se|odtáhnout_se|
odtrhnout_se|odvážit_se|odvažovat_se|odvděčit_se|odvděčovat_se|odvíjet_se|odvinout_se|
odvolat_se|odvolávající_se|odvolávat_se|odvracet_se|odvrátit_se|odvyknout_si|ohánějící_se|
ohánět_se|ohlásit_se|ohlédnout_se|ohlížet_se|ohradit_se|ohřát_se|ohřát_si|ohrazovat_se|
ohýbat_se|okázat_se|okoukat_se|oloupat_se|omezit_se|omezovat_se|opakovat_se|opakovat_si|
opakující_se|opalovat_se|opařit_se|opíjet_se|opírající_se|opírat_se|opít_se|oprat_se|
opřít_se|optat_se|organizovat_se|orientovat_se|orosit_se|osahat_si|osamostatnit_se|
oslabovat_se|osobovat_si|ostýchat_se|osvědčit_se|osvědčovat_se|osvobodit_se|osvojit_si|
osvojovat_si|otáčet_se|otázat_se|oteplit_se|oteplovat_se|otevírat_se|otevření_se|otevřít_se|
otírávat_se|otisknout_se|otočit_se|otřást_se|otrávit_se|otravovat_se|otrkat_se|otvírat_se|
ovládnout_se|oženit_se|ozvat_se|ozývat_se|pálit_se|pálit_si|pamatovat_se|pamatovat_si|
patřit_se|patřívat_se|pídit_se|pinkat_si|plácat_se|plašit_se|plavit_se|plazit_se|plést_se|
plést_si|plnit_se|plnit_si|pobavit_se|pobouřit_se|pobrukovat_si|pochlubit_se|pochutnat_si|
pochvalovat_si|počíhat_si|počínat_se|počínat_si|počíst_si|počít_si|počkat_si|podařit_se|
podat_si|podbízet_se|poděkovat_se|podělit_se|podepisovat_se|podepsat_se|podílet_se|podít_se|
podívat_se|podivit_se|podivovat_se|podmanit_si|podobat_se|podpisovat_se|podřídit_se|
podřízení_se|podrobit_se|podrobit_si|podrobovat_se|podržet_se|podržet_si|podvolit_se|
podvolovat_se|pohádat_se|pohladit_si|pohnout_se|pohoršit_si|pohrát_si|pohrávat_si|pohřbít_se|
pohroužit_se|pohybovat_se|pohybující_se|pojit_se|pojívat_se|pokazit_se|pokládat_se|
poklonit_se|pokořit_se|pokoušející_se|pokoušet_se|pokrčit_se|pokusit_se|polekat_se|
polepšit_se|polepšit_si|polít_se|položit_se|pominout_se|pomoci_si|pomočit_se|pomodlit_se|
pomstít_se|pomyslet_si|pomyslit_si|ponořit_se|popadnout_se|poplést_se|poplést_si|
popletení_se|popovídat_si|poprat_se|poradit_se|poradit_si|poranit_se|pořezat_se|
poroučívat_se|porovnat_se|porvat_se|posadit_se|posílit_se|poslechnout_si|posloužit_si|
posmívat_se|posouvat_se|pospíšit_si|postarat_se|postavit_se|postavit_si|postesknout_si|
poštěstit_se|postěžovat_si|postýskávat_si|posunout_se|posunovat_se|pošušňávat_si|posvítit_si|
potácet_se|potěšit_se|potit_se|potkat_se|potopit_se|potrpět_si|potvrdit_se|potvrzovat_se|
potýkat_se|poučit_se|poučovat_se|poučující_se|pousmát_se|pouštět_se|poutávat_se|považovat_se|
považovat_si|považující_se|pověsit_se|povést_se|povídat_si|povšimnout_si|povyšovat_se|
povzdechnout_si|povznést_se|pozastavit_se|pozastavovat_se|pozdravit_se|pozdvihnout_se|
pozměnit_se|poznat_se|pozvednout_se|praštit_se|přátelit_se|prát_se|přát_si|přebírat_se|
přečíst_si|předat_se|předávkovat_se|předběhnout_se|předbíhat_se|předcházet_se|předcházet_si|
předsevzít_si|představit_se|představit_si|představovat_se|představovat_si|předvádět_se|
předvést_se|přehazovat_se|přehazovat_si|přehlédnout_se|přehnat_se|přehřát_se|přehrávat_se|
překonat_se|překonávat_se|překrýt_se|přelidnit_se|přelít_se|přeměnit_se|přemístit_se|
přenášet_se|přenést_se|přeorientovat_se|přepočítat_se|přepravit_se|přerušit_se|přesouvat_se|
přestěhovat_se|přesunout_se|přesunovat_se|přesvědčit_se|přesvědčovat_se|přetahovat_se|
přetavit_se|převalovat_se|převážit_se|převrátit_se|převrhnout_se|převzít_si|prezentovat_se|
přežít_se|přiblížení_se|přiblížit_se|přibližování_se|přibližovat_se|přicházet_si|
přichystat_se|přičinit_se|přidat_se|přidávat_se|přidržet_se|přihlášení_se|přihlásit_se|
přihlašování_se|přihodit_se|přihřát_se|přihřát_si|přijít_si|přiklánět_se|přiklonit_se|
přilepit_se|přimíchat_se|přimknout_se|připadat_si|připojení_se|připojit_se|připojovat_se|
připouštět_si|připravit_se|připravovat_se|připustit_si|přiřadit_se|přiřazovat_se|přiřítit_se|
příslušet_se|přistěhovat_se|přisvojit_si|přitisknout_se|přitížit_se|přít_se|přiučit_se|
přivítat_se|přivlastnit_si|přivlastňovat_si|přivydělat_si|přivydělávat_si|přiživovat_se|
přiznat_se|přiznávat_se|přizpůsobit_se|přizpůsobovat_se|proběhnout_se|probírat_se|probít_se|
probojovat_se|probouzet_se|probrat_se|probudit_se|procházet_se|prodírat_se|prodloužit_se|
prodlužovat_se|prodrat_se|prodražit_se|prodražovat_se|prohlédnout_si|prohlížet_si|
prohloubit_se|prohlubovat_se|prohnat_se|prohřešit_se|projet_se|projevit_se|projevovat_se|
projít_se|prokázat_se|prokousat_se|prolámat_se|prolínat_se|prolnout_se|prolomit_se|
proměnit_se|proměňovat_se|promíchat_se|promítat_se|promítnout_se|promluvit_si|pronést_se|
propadání_se|propadnout_se|propálit_se|proplétat_se|propojit_se|propracovat_se|
propracovávat_se|prořeknout_se|prosadit_se|prosazení_se|prosazovat_se|prosekat_se|prosit_se|
proslavit_se|proslýchat_se|prospat_se|prostavět_se|prostituovat_se|protáhnout_se|protnout_se|
protrhávat_se|protrhnout_se|provdat_se|provinit_se|prozradit_se|ptát_se|ptávat_se|půjčit_si|
půjčovat_si|pustit_se|pustit_si|pyšnit_se|pyšnívat_se|radit_se|řadit_se|radovat_se|
realizovat_se|rekrutovat_se|rekvalifikovat_se|reprodukovat_se|řezat_se|říci_si|řídící_se|
řídit_se|říkat_si|říkávat_si|řítit_se|rodit_se|rojit_se|rouhající_se|rovnající_se|rovnat_se|
rovnat_si|rozběhnout_se|rozbíhat_se|rozbít_se|rozcházet_se|rozčilovat_se|rozcvičovat_se|
rozdat_si|rozdělit_se|rozdrtit_se|rozednívat_se|rozehrát_se|rozejít_se|rozesmát_se|
rozevřít_se|rozházet_si|rozhlédnout_se|rozhlížet_se|rozhněvat_se|rozhodnout_se|rozhodovat_se|
rozhořčovat_se|rozhořet_se|rozhorlit_se|rozhostit_se|rozhoupat_se|rozhovořit_se|rozjet_se|
rozjíždět_se|rozkládat_se|rozklepat_se|rozléhat_se|rozlehnout_se|rozloučit_se|rozložit_se|
rozmáhat_se|rozmístit_se|rozmlouvávat_se|rozmýšlet_se|rozmyslet_si|rozmyslit_si|
rozpadající_se|rozpadat_se|rozpadnout_se|rozpakovat_se|rozpíjet_se|rozpínat_se|rozplakat_se|
rozplynout_se|rozplývat_se|rozpočíst_se|rozpomínat_se|rozpoutat_se|rozpovídat_se|
rozprostírat_se|rozptýlit_se|rozptylovat_se|rozpustit_se|rozřeďovat_se|rozrůstat_se|
rozrůst_se|rozšířit_se|rozšiřovat_se|rozsvítit_se|rozsypat_se|rozsypávat_se|roztáhnout_se|
roztahovat_se|roztavit_se|roztrhat_se|roztrhnout_se|rozumět_se|rozumět_si|rozvádět_se|
rozvést_se|rozvětvovat_se|rozvíjející_se|rozvíjet_se|rozvinout_se|rozvinovat_se|rozvodnit_se|
rozzářit_se|rozzlobit_se|různit_se|rvát_se|rýpnout_si|rýsovat_se|sázet_se|sbalit_se|
sbíhat_se|sbírat_se|sblížit_se|scházet_se|scházívat_se|schovat_se|schylovat_se|scvrknout_se|
sdružit_se|sdružovat_se|seběhnout_se|sebrat_se|sednout_si|sehrát_se|sejít_se|sestoupit_se|
sesunout_se|sesypat_se|setkat_se|setkávat_se|sevřít_se|seznámit_se|seznamovat_se|shánět_se|
shledat_se|shluknout_se|shlukovat_se|shodit_se|shodnout_se|shodovat_se|shrnout_se|
shromáždit_se|shromažďovat_se|šířit_se|sjednotit_se|sjet_se|sjíždět_se|skládat_se|sklánět_se|
sklonit_se|sklouznout_se|skončit_se|skoncovat_se|skrývat_se|skvět_se|slehnout_se|slepit_se|
slévat_se|slibovat_si|sloučit_se|složit_se|slučovat_se|slunit_se|slušet_se|smát_se|
smávat_se|smáznout_se|smíchat_se|smířit_se|smiřovat_se|smrákat_se|smrštit_se|snažící_se|
snažit_se|snažívat_se|snést_se|snít_se|snít_si|snížit_se|snižovat_se|snoubit_se|soudit_se|
šoustnout_si|soustředit_se|soustřeďovat_se|soustřeďující_se|spadnout_se|spálit_se|spalovat_se|
spasit_se|specializovat_se|specializující_se|splést_se|šplhat_se|šplhnout_si|splnit_se|
spočítat_si|spojit_se|spojovat_se|spokojit_se|spokojovat_se|spolčit_se|spoléhat_se|
spolehnout_se|spolupodílet_se|spřátelit_se|spravit_se|spustit_se|srazit_se|srovnat_se|
srovnat_si|stabilizovat_se|stáhnout_se|stahování_se|stahovat_se|starat_se|stát_se|stát_si|
stávat_se|stavějící_se|stavět_se|stavět_si|stavit_se|stěhovat_se|stěhovávat_se|štěpit_se|
stěžovat_si|stisknout_se|stísnit_se|štítící_se|štítit_se|stmívat_se|stočit_se|stoupnout_si|
strachovat_se|stravovat_se|strčit_si|střetávat_se|střetnout_se|střežit_se|strhávat_si|
strhnout_se|střídat_se|střídávat_se|střílet_si|strkat_se|stupňovat_se|štvávat_se|stydět_se|
stýkat_se|stýkávat_se|stýskat_se|stýskávat_se|stýskávat_si|sunout_se|sužovat_se|svažovat_se|
svěřit_se|svěřovat_se|svézt_se|svlékávat_se|sypat_se|sypávat_se|sžít_se|tahat_se|táhnout_se|
tajit_se|tázat_se|tenčit_se|těšící_se|těšit_se|těšívat_se|tisknout_se|tlačit_se|
tloukávat_se|točit_se|topit_se|toulat_se|toulávat_se|transformovat_se|transformující_se|
trápit_se|trápívat_se|třást_se|trefit_se|trefovat_se|třepetat_se|trhávat_se|trhnout_se|
třít_se|troufat_si|troufnout_si|tvářit_se|tvořící_se|tvořit_se|tvořívat_se|tyčit_se|
týkající_se|týkat_se|ubírat_se|ubránit_se|ubytovat_se|účastnící_se|účastnit_se|ucházející_se|
ucházení_se|ucházet_se|uchovat_se|uchránit_se|uchýlit_se|uchylovat_se|uchytit_se|učit_se|
učívat_se|ucpat_se|účtovat_si|udát_se|udělat_se|udělat_si|udeřit_se|udržet_se|udržet_si|
udusit_se|uhnízdit_se|uhodit_se|ujasnit_si|ujímat_se|ujistit_se|ujmout_se|ukázat_se|
ukáznit_se|ukazovat_se|ukládat_se|uklidit_se|uklidnit_se|uklidňovat_se|uklonit_se|ukrýt_se|
ukvapit_se|ulehčit_se|ulevit_se|ulevit_si|uložit_se|umanout_si|umínit_si|umístit_se|
umísťovat_se|umoudřit_se|unavit_se|upevnit_se|upínat_se|upisovat_se|upít_se|uplatnit_se|
uplatňovat_se|upnout_se|upnutí_se|upravit_se|upřít_se|upsat_se|urazit_se|usadit_se|
usazovat_se|ušetřit_si|usídlit_se|ušklíbnout_se|uskromnit_se|uskrovnit_se|uskutečnit_se|
uskutečňovat_se|usmát_se|usmířit_se|usmívat_se|usnést_se|ustálit_se|ustalovat_se|
ustanovit_se|ustát_se|utábořit_se|utahovat_si|utéci_se|utěšit_se|utkat_se|utkávat_se|
utnout_se|utopit_se|utrhat_se|utrhnout_se|utvářet_se|utvářit_se|utvořit_se|uvařit_se|
uvědomit_si|uvědomování_si|uvědomovat_si|uvědomující_si|uvést_se|uvidět_se|uvítat_se|
uvolit_se|uvolnit_se|uvolňovat_se|uzavírat_se|uzavřít_se|uzdravit_se|užírat_se|užít_si|
užívat_si|uživit_se|uzlit_se|vadívat_se|válet_se|valit_se|valívat_se|vařit_se|varovat_se|
vázat_se|vážící_se|vážit_si|vcítit_se|vdát_se|vdávat_se|vědět_si|vědomý_si|vejít_se|
věnovat_se|věnující_se|vepsat_se|veselit_se|vést_se|vést_si|vetřít_se|vézt_se|vidět_se|
vidívat_se|vítat_se|vít_se|vkrádat_se|vláčívat_se|vléci_se|vlnit_se|vloupat_se|vložit_se|
vměšovat_se|vmíchat_se|vnést_se|vnucovat_se|vnutit_se|vodívat_se|vozit_se|vozívat_se|
vpíjet_se|vpravovat_se|vracející_se|vracet_se|vracívat_se|vrátit_se|vrazit_se|vrcholit_se|
vrhat_se|vrhnout_se|vřítit_se|vrtívat_se|vrýt_se|vsadit_se|všímat_si|všimnout_si|vsunout_se|
vtáhnout_se|vtírat_se|vtisknout_se|vybavit_se|vybavit_si|vybavovat_se|vybourat_se|vybrat_se|
vyčerpat_se|vychutnat_si|vyčistit_se|vyčlenit_se|vyčleňovat_se|vycucat_si|vydařit_se|
vydat_se|vydávat_se|vydechnout_si|vydělat_se|vydělit_se|vydělovat_se|vyděsit_se|vydlužit_si|
vydovádět_se|vydrat_se|vydýchat_se|vyhnout_se|vyhodit_si|vyhoupnout_se|vyhradit_si|
vyhranit_se|vyhraňovat_se|vyhrát_se|vyhrát_si|vyhřívat_se|vyhrkat_se|vyhrnout_se|
vyhrocovat_se|vyhrotit_se|vyhýbání_se|vyhýbat_se|vyjádřit_se|vyjadřovat_se|vyjasnit_se|
vyjasnit_si|vyjasňovat_se|vyjet_si|vyjímat_se|vyjít_si|vykázat_se|vykládat_si|vyklidit_se|
vyklubat_se|vykoupat_se|vykrást_se|vykreslit_se|vyléčit_se|vylepšit_se|vylhávat_se|
vylidnit_se|vylít_se|vylít_si|vylízat_se|vylodit_se|vyloučit_se|vyloupnout_se|vylučovat_se|
vymanit_se|vymezit_se|vymezování_se|vymínit_si|vymiňovat_si|vymknout_se|vymlouvat_se|
vymluvit_se|vymočit_se|vymstít_se|vymykat_se|vymyslet_si|vymýšlet_si|vymyslit_si|
vynacházet_se|vynášet_se|vynést_se|vynořit_se|vynořovat_se|vynucovat_si|vynutit_si|
vyostřit_se|vyostřovat_se|vypínat_se|vypít_si|vyplácet_se|vyplatit_se|vyplnit_se|vypnout_se|
vypořádání_se|vypořádat_se|vypořádávat_se|vypovídat_se|vypracovat_se|vypravit_se|
vyprofilovat_se|vyprostit_se|vyptat_se|vyptávat_se|vypůjčit_si|vypůjčovat_si|vyrazit_se|
vyrazit_si|vyřídit_se|vyřídit_si|vyříkat_si|vyrovnání_se|vyrovnat_se|vyrovnávat_se|
vyskakovat_si|vyskytnout_se|vyskytovat_se|vyšlápnout_si|vyslechnout_si|vysloužit_si|
vyslovit_se|vyslovovat_se|vysmát_se|vysmívat_se|vysnívat_si|vysouvat_se|vyspat_se|
vyšplhat_se|vystačit_si|vystěhovat_se|vystřelit_si|vystřídat_se|vystříhat_se|vysunout_se|
vysvětlit_si|vysvětlovat_si|vyšvihnout_se|vysypat_se|vytáčet_se|vytáhnout_se|vytasit_se|
vytočit_se|vytrácet_se|vytratit_se|vytrhnout_se|vytříbit_se|vytrpět_si|vytvářet_se|
vytvořit_se|vyučit_se|vyvalit_se|vyvarovat_se|vyvěsit_se|vyvést_se|vyvíjet_se|vyvinout_se|
vyvléknout_se|vyvrátit_se|vyžádat_si|vyžadovat_si|vyzářit_se|vyzkoušet_si|vyznačovat_se|
vyznamenat_se|vyznat_se|vyzpovídat_se|vzbouřit_se|vzbudit_se|vzdálit_se|vzdalovat_se|
vzdalující_se|vzdát_se|vzdávat_se|vzít_se|vžít_se|vzít_si|vznášet_se|vznést_se|vznítit_se|
vzpamatovat_se|vzpamatovávat_se|vzpínat_se|vzpírat_se|vzpomenout_si|vzpomínat_si|vzrušit_se|
vztahovat_se|vztahující_se|vztyčit_se|zabíjet_se|zabít_se|zablokovat_se|zabrat_se|
zabydlet_se|zabývající_se|zabývat_se|zacelit_se|zachovat_se|zachovat_si|zachránit_se|
zachvět_se|zachytit_se|začínat_si|začíst_se|začít_si|začlenit_se|zadat_si|žádávat_si|
zadívat_se|zadlužit_se|zadrhnout_se|zahalit_se|zaházet_si|zahledět_se|zahltit_se|zahodit_se|
zahojit_se|zahřát_se|zahrát_si|zahrávat_si|zahýbat_se|zajet_si|zajímající_se|zajímat_se|
zajít_si|zakázat_si|zakládat_se|zakládat_si|zaklepat_se|zakončit_se|zakopat_se|zakoukat_se|
zakoupit_se|zakousnout_se|zakřičet_si|zakusovat_se|zaleknout_se|zalíbit_se|zalít_se|
zamanout_si|zaměřit_se|zaměřovat_se|zamíchat_se|zamilovat_se|zamilovat_si|zamlouvat_se|
zamnout_si|zamračit_se|zamyslet_se|zamýšlet_se|zamyslit_se|zanášet_se|zanést_se|zanořovat_se|
zapálit_se|zapálit_si|zapalovat_se|zapamatovat_si|zaplatit_se|zaplavit_se|zaplést_se|
zaplnit_se|zapojit_se|zapojovat_se|zapomenout_se|zapotit_se|zapřít_se|zaprodávat_se|
zapsat_se|zapůjčit_si|zařadit_se|zaradovat_se|zařazení_se|zarazit_se|zařeknout_se|zařídit_se|
zaručit_se|zarývat_se|zasadit_se|zasazovat_se|zasednout_si|zasloužit_se|zasloužit_si|
zasluhovat_se|zasluhovat_si|zasmát_se|zasmečovat_si|zastat_se|zastávat_se|zastavit_se|
zastavovat_se|zastřelit_se|zastřít_se|zastydět_se|zatáhnout_se|zatajit_se|zatelefonovat_si|
zatočit_se|zatoulat_se|zatrénovat_si|zatřepat_se|zatvářit_se|zaujmout_se|zavázat_se|
zavazovat_se|zavděčit_se|zavěsit_se|zavést_se|závodit_si|zavřít_se|završit_se|zavrtět_se|
zavzpomínat_si|zažít_se|zbavení_se|zbavit_se|zbavovat_se|zbláznit_se|zbořit_se|zbortit_se|
zbrzdit_se|zbýt_se|zdařit_se|zdát_se|zdávat_se|zděsit_se|zdokonalovat_se|zdráhat_se|
zdráhávat_se|zdržet_se|zdržovat_se|zdvihávat_se|zdvojnásobit_se|zdvojnásobovat_se|zelenat_se|
ženit_se|zeptat_se|zesilovat_se|zformovat_se|zhlížet_se|zhlížívat_se|zhmotňovat_se|
zhodnotit_se|zhoršit_se|zhoršovat_se|zhostit_se|zhroutit_se|získat_si|žít_si|živit_se|
zjasňovat_se|zjednodušit_se|zjevit_se|zjevovat_se|zjevovávat_se|zkazit_se|zklamat_se|
zkomplikovat_se|zkoncentrovat_se|zkonsolidovat_se|zkoušet_si|zkrátit_se|zkusit_si|zlámat_se|
zlepšit_se|zlepšovat_se|zlíbit_se|zlobit_se|zlobívat_se|zlomit_se|zmačkat_se|zmařit_se|
zmást_se|změnit_se|zmenšit_se|zmínit_se|zmiňovat_se|zmírnit_se|zmítat_se|zmoci_se|
zmocnit_se|zmýlit_se|znát_se|znávat_se|znechutit_se|znehodnotit_se|znepokojit_se|
znepřátelit_si|zobrazit_se|zodpovědět_se|zodpovídat_se|zopakovat_se|zorganizovat_se|
zorientovat_se|zpevnit_se|zpomalit_se|zpozdit_se|zpožďovat_se|zpronevěřit_se|zračit_se|
zranit_se|žrát_se|zrcadlit_se|zredukovat_se|zřeknout_se|zříci_se|zříkat_se|zřítit_se|
zrodit_se|zrychlit_se|zrychlovat_se|ztenčit_se|ztížit_se|ztotožnit_se|ztotožňovat_se|
ztrácet_se|ztratit_se|ztrojnásobit_se|zúčastnit_se|zúčastňovat_se|zúročit_se|zúžit_se|
zvedat_se|zvednout_se|zvětšit_se|zvětšovat_se|zvrátit_se|zvrhnout_se|zvykat_si|zvyknout_si|
zvýraznit_se|zvýšit_se|zvyšovat_se|zvyšující_se|zželet_se|rozednít_se|(za|roz|)chechtat_se";

sub is_possible_tantum {

    my ($lemma) = @_;

    return $lemma =~ /^($possible_tantums)$/sxm;
}

1;

__END__

=pod

=head1 NAME

Treex::Tool::Lexicon::CS::Reflexivity

=head1 SYNOPSIS

 use Treex::Tool::Lexicon::CS::Reflexivity;

 foreach my $lemma (qw(chodit zeptat troufat)) {
     print Treex::Tool::Lexicon::CS::Reflexivity::fix_reflexivity($lemma)."\n";
 }

 if (!Treex::Tool::Lexicon::CS::Reflexivity::is_possible_tantum('zvýhodnit_se')){
     # do something about it
 }

=head1 DESCRIPTION

=over 4

=item my $corrected_tlemma = Treex::Tool::Lexicon::CS::Reflexivity::fix_reflexivity($tlemma);

If the given Czech verb lemma is reflexivum tantum,
then the reflexive suffix "_si" or "_se" is added to the lemma.
Based on a list of reflexives extracted from VALLEX 2.5.

=item my $bool = Treex::Tool::Lexicon::CS::Reflexivity::is_possible_tantum($tlemma)

Returns true only if the given lemma (such as "ptát_se", "jistý_si", "kolísat_se") is on the list
of possible reflexive tantums (which is not true for the last example). The list is based on
VALLEX 2.5, PDT-VALLEX 2.0 and the PDT 2.0 data.

=back

=cut

=head1 TODO

The list of possible reflexives should be probably narrowed down, since it contains also verbs in which
the reflexive tantum variant from the dictionary is either highly unlikely to occur (e.g. "dělat_se" as
in "Dělá se hezky.") or not entirely justifiable (e.g. "seznámit se" or "zabít se").

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
