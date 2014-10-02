package Treex::Tool::Lexicon::NL::ErgativeVerbs;

use utf8;
use strict;
use warnings;

my %IS_ERGATIVE_VERB;
while (<DATA>) {
    for (split) {
        $IS_ERGATIVE_VERB{$_} = 1;
    }
}
close DATA;

sub is_ergative_verb {
    return $IS_ERGATIVE_VERB{ $_[0] }
}

1;

=encoding utf8

=head1 NAME

Treex::Tool::Lexicon::NL::ErgativeVerbs

=head1 SYNOPSIS

 use Treex::Tool::Lexicon::NL::ErgativeVerbs;
 print Treex::Tool::Lexicon::NL::ErgativeVerbs::is_ergative_verb('gaan');
 # prints 1

=head1 DESCRIPTION

A list of Dutch egrative verbs such as I<gaan, zijn, zwemmen,...> (taken from Dutch
Wiktionary). These verbs build their past tense with I<zijn> and don't build passive
forms.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

__DATA__

aanbakken aanbelanden aanblijven aanbreken aandrijven aaneengroeien
aaneenknopen aanflitsen aanfloepen aangaan aangroeien aanhouden aankoeken
aankomen aanlanden aanliggen aanlopen aanschikken aanschuiven aansluiten
aanspoelen aansterken aansterven aanstevenen aanstiefelen aanstuiven aantreden
aantrekken aanvangen aanvaren aanvliegen aanwassen aanwippen aanzetten
aanzwellen acclimatiseren accumuleren achterblijven achternarijden
achteroverslaan achteruitgaan adelen afbladderen afblijven afbranden
afbrokkelen afdalen afdrijven afdruipen afgaan afglijden afhaken afkalven
afketsen afkoelen afkomen afleken aflopen afnemen afnokken afreizen afremmen
afscheuren afschilferen afslaan afslanken afslijten afspoelen afstammen
afstompen afstuderen aftaaien aftakelen aftreden aftrekken afvallen afwijken
afzakken afzweren agglutineren arriveren asfyxiëren assimileren barsten bedaren
bederven begroeien beharen bekanen bekomen belanden benen bersten beschimmelen
beslaan besterven betrekken bevallen bevriezen bewolken bezinken bezwijken
bezwijmen bijblijven bijeenkomen bijkomen bijschuiven bijspringen bijtrekken
bijvallen binnenblijven binnendringen binnengaan binnenkomen binnenlopen
binnentrekken binnenvallen bladderen blijven bloezen boemelen botsen
bovenblijven bovenkomen breken brommen bronzen buitelen chambreren coaguleren
collaberen compareren condenseren convergeren copolymeriseren creperen crossen
cumuleren dalen dampen dartelen daveren davvenen de-escaleren decompenseren
deconfessionaliseren degenereren degraderen dehydrateren deinzen democratiseren
demonstreren derailleren deserteren destabiliseren detoneren devalueren
dichtslibben dichtvriezen dippen dissociëren dobberen donderen doodblijven
doodbloeden doodgaan doodlopen doodvallen doorbreken doorbuigen doordraaien
doordringen doorrijden doorschieten doorsteken doortrekken doorvloeien draaien
dretsen dribbelen drijven drogen droppen druipen druppelen druppen dubbelslaan
duikelen duiken dwalen dwarrelen emigreren emulgeren eroderen escaleren
evacueren evaporeren evolueren expanderen expireren exploderen federeren
filteren finishen fladderen flauwvallen fragmenteren gaan garen gebeuren
gedijen genezen geraken geschieden gijpen gisten glijden gnuiven grijzen
groeien groenen gutsen harden heengaan heenlopen heenrijden heenvlieden helen
herbeginnen herleven herrijzen herstellen hertrouwen hervallen hinken hippen
hollen huppelen huppen huwen immigreren imploderen inbranden inburgeren
inclineren indommelen indringen industrialiseren ineensmelten ineenstorten
infiltreren ingaan inklappen inklimmen inklinken inkomen inkrimpen inkruipen
inlopen inrukken inslaan inslapen insneeuwen inspringen instorten integreren
intreden invallen invaren invliegen inzetten ioniseren isomeriseren
italianiseren jakkeren joggen kaatsen kabbelen kalen kalmeren kanaalzwemmen
kantelen kapitaliseren kappen kapseizen karameliseren karamelliseren kelderen
keren klaarkomen klappen klaren kleuren klonteren klotsen klunen knallen
knappen koeken koken kolken komen kreukelen kreuken krimpen kristalliseren
kroezen kromtrekken kronkelen kruien kruimen kruipen kuieren kukelen kwijtraken
kwijtspelen landen langlaufen langskomen laveren lazeren leegbloeden leeglopen
lengen liggen lobberen lopen losbarsten losschieten losslaan lukken luwen
marcheren meanderen meedeinen meedrijven meegaan meekomen meelopen meerijden
meevallen meevaren meevliegen migreren mineraliseren misgaan mislopen mislukken
muteren nabijblijven nabijkomen nablijven naduiken nagaan naken nasporen
navolgen neerploffen neersijpelen neerslaan neerstorten neigen omdraaien omgaan
omhooggaan omkeren omkieperen omkomen omkukelen omlaaggaan omrijden omslaan
omvallen omverwaaien omwaaien omzeilen onderduiken ondergaan onderlopen
ondersneeuwen onderstromen ontaarden ontbinden ontbranden ontdooien ontgaan
ontkiemen ontkomen ontleden ontlopen ontluiken ontmenselijken ontploffen
ontrollen ontsnappen ontsporen ontspringen ontspruiten ontstaan ontsteken
ontstemmen ontvallen ontvlammen ontvluchten ontvolgen ontvolken ontwaken
ontwennen ontwijken ontzilten ontzuilen opblijven opbloeien opborrelen
opbranden opbreken opbruisen opdagen opdoemen opdonderen opdraaien opdringen
opdrogen opduiken openblijven openbreken opengaan openzwaaien opfleuren
opflikkeren opgaan opgroeien ophoepelen ophouden opklaren opklimmen opknappen
opkomen oplaaien oplichten oploeven oplopen oplossen opmonteren oprijzen
oprotten opschieten opspuiten opstaan opstijgen opstuiven optreden optrekken
optyfen opvallen opvliegen opwarmen opwassen opzetten opzwellen overdrijven
overeenkomen overgaan overkoken overkomen overlijden overrijden overslaan
oversteken overtrekken overvaren overvliegen oxideren peddelen penetreren
pensioneren peptiseren ploegen ploeteren ploffen plonzen polymeriseren
postvatten racemiseren raken rammelen recupereren reduceren regenereren rennen
repatriëren revalideren rijden rijmen rijzen roeien romaniseren ronddraaien
rondkomen rondlopen rondvaren roteren rotten samenblijven samenkomen
samensmelten samenvallen scharrelen schavelen schavielen scheefgroeien scheiden
schepen scheuren schieten schiften schoolblijven schoolgaan schrijden schrikken
schroeien schrompelen schuifelen siepelen sieperen sijpelen sijperen sjezen
sjokken skiën slaan slagen slenteren slijten slingeren slinken slippen slooien
sluipen smelten smeren sneuvelen sneven snorren snowboarden splijten sprieten
springen sprinten spruiten spuiten stabiliseren stagneren stappen starten
sterven stevenen stijgen stikken stilvallen stoelen stollen stormen stranden
stremmen stromen struikelen stuiten stuiteren stuiven stukgaan stukslaan
sublimeren suizen sullen tegeneten tegenkomen tegenvallen tekeergaan
tekortschieten teloorgaan tenietgaan terechtkomen terugdeinzen terugdrijven
teruggaan terugkaatsen terugkelderen terugkeren terugkomen teruglopen
terugschrikken terugtreden terugvallen thuisblijven thuiskomen toenemen toeren
toestromen toetreden totaliseren transmuteren treden trekken trouwen
tussenkomen uitbarsten uitblijven uitbreken uitdijen uitdoven uitdraaien
uitdunnen uiteenlopen uiteenspatten uiteenvallen uitgaan uitglijden uitgroeien
uitkomen uitlekken uitlopen uitpakken uitregenen uitrijden uitrollen uitrukken
uitscheiden uitschrijven uitslaan uitslijten uitspringen uitspuiten uitstappen
uitsterven uittreden uittrekken uitvallen uitvaren uitwijden uitwijken
uitzetten vallen vastvriezen verachtvoudigen veramerikaansen veranderen
verarmen verbeteren verbleken verbloeden verbranden verburgerlijken verdampen
verdeluwen verdergaan verdichten verdierlijken verdikken verdorren
verdrievoudigen verdrinken verdrogen verdubbelen verdunnen verdwalen verdwijnen
vereelten verergeren verfomfaaien verfransen vergaan vergassen vergelen
vergisten verglazen verglijden vergroeien verhevigen verhongeren verhufteren
verhuizen verjaren verkalken verkolen verkrampen verkruimelen verlijden
verlijeren verloederen verlopen vermageren verminderen vermolmen vernikkelen
verongelukken verouderen verrekken verrijzen verrotten versagen verscheiden
verschieten verschijnen verschimmelen verschroeien verschrompelen verschuiven
verslechteren verslijpen verslijten verspringen verstarren verstenen verstijven
verstommen verstoppen verstrijken verstuiven versuffen verteren vertrekken
vervalen vervallen vervellen vervetten vervliegen vervlieten vervormen
vervuilen verwateren verweken verwelken verweren verwesteren verwilderen
verworden verzadigen verzanden verzengen verzinken verzitten verzuipen verzuren
verzwakken verzweren vlieden vlieten vlinderen vloeien vluchten voeteren volgen
volkomen vollopen vonken voorbijfietsen voorbijgaan voordringen voorijlen
voorkomen voorovervallen voortgaan voortkomen voortschrijden voortsjokken
voortvluchten vooruitgaan vooruitkomen vooruitlopen vooruitsteken voorvallen
vorderen vreemdgaan waggelen wandelen wankelen waren warmlopen
weeromkeren wegblijven wegdoezelen wegdommelen wegebben weggaan weghollen
weghuppelen wegijlen wegkomen wegkruipen wegkwijnen weglopen wegraken wegrennen
wegrijden wegslaan wegslinken wegsluipen wegspringen wegsterven wegstormen
wegteren wegtrekken wegvallen wegvliegen wegwezen wegzinken wegzwemmen weken
welvaren wenden wervelen wezen wijken willigen woekeren worden wortelen
wrongelen wurmen zakken zieden zigzaggen zijgen zijn zijpelen zijpen zinken
zitten zoekraken zoeven zwammen zwellen zwemmen zwichten zwieren
