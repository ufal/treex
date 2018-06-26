package Treex::Tool::Lexicon::CS::PersonalRoles;
use utf8;
use strict;
use warnings;

my %IS_PERSONAL_ROLE;
while (<DATA>) {
    for (split) {
        $IS_PERSONAL_ROLE{$_} = 1;
    }
}
close DATA;

sub is_personal_role {
    return 1 if $_[0] =~ /^\p{Lowercase}.*([^pd]oložka|[^s]kyně|[^v][aá]řka|[^jč]istka)$/;
    return $IS_PERSONAL_ROLE{ $_[0] }
}

1;

=encoding utf8

=head1 NAME

Treex::Tool::Lexicon::CS::PersonalRoles

=head1 SYNOPSIS

 use Treex::Tool::Lexicon::CS::PersonalRoles;
 print Treex::Tool::Lexicon::CS::PersonalRoles::is_personal_role('herec');
 # prints 1

=head1 DESCRIPTION

A list of personal roles which such as I<herec, mnich, mim,...>.

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2010-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut

__DATA__

abbé absolvent absolventka advokát advokátka agent agentka akademik akademička
aktivista amatér ambasador ambasadorka analytička analytik anděl archeolog archeoložka architekt architektka arcibiskup
asistent asistentka astronom atlet auditor auditorka automechanik autor autorka baba babička
banjista bankéř bankéřka baron baronka barytonista basista basketbalista baskytarista básník
básnířka běžec bibliofil biochemik biolog bioložka biskup bohemista bohemistka
bojovník bojovnice botanik botanička boxer brácha brankář bratr bratranec bratříček bubeník bubenice
budovatel budovatelka car čaroděj čarodějka cellista černoch černoška cestovatel cestovatelka chargé chemik chirurg
chlap chlapec choreograf choreografka choť chudák činovník činovnice císař číšník číšnice
cizinec cizinka člen členka člověk čtenář cvičitelka cyklista dáma dcera
dealer dědeček dědic dědička dějepisec děkan děkanka delegát delgátka dělník dělnice desetibojař
diplomat dirigent dirigentka divadelník divedelnice divák divačka dívka dobrodruh docent docentka dodavatel dodavatelka doktor
doktorka dopisovatel dopisovatelka dozorce dramatička dramatik dramaturg dramaturgyně držitel
držitelka důchodce důstojník důstojnice editorka ekolog ekonom
ekonomka elektrotechnik emigrant epidemiolog epidemioložka estetik etnograf etnolog exmanžel exmanželka
exministr expert expertka expremiér farář farmář favorit filolog filoložka
filozof filosof filozofka finalista flétnista fořt fotbalista fotograf fotografka
frontman funkcionář fyzik garant garantka generál generálmajor génius geograf geografka geolog geoložka
gólman grafik grafička guvernér guvernérka gynekolog gynekoložka herec herečka historička historik hlasatel hlasatelka
hoch hokejista horník horolezec hospodář hospodyně host hostinský hostinská houslista
hrabě hraběnka hráč hráčka hrdina hrdinka hudebník hudebnice hygienik hygienička
idol ikona ilustrátor ilustrátorka imitátor imitátorka iniciátor iniciátorka informátor informátorka inspektor inspektorka
instruktor instruktorka instalatér internista investor investorka
inženýr inženýrka jednatel jednatelka jezdec jinoch junior juniorka kacíř kacířka kadeřnice kamarád kamarádka kamelot
kameník kameraman kameramanka kancléř kancléřka kandidát kandidátka kanoista kanonýr
kapelník kapelnice kapitán kapitánka kaplan kardinál kardiolog kardioložka kat keramik keramička kladivář klasik klávesista klávesistka
klavírista kluk kněz kněžna knihovník knihovnice kočí kolega kolegyně
komentátor komentátorka komik kominice komisař komisionář komorník komornice komunista konstruktér konstruktérka
kontrabasista konzultant konzultantka koordinátor koordinátorka koproducent koproducentka
korektor korektorka kosmonaut kosmonautka kostelník kostelnice
kouč koučka koulař kovář kovářka král královna krejčí kreslíř kreslířka křesťan křesťanka
kritik kritička kuchař kulak kurátor kurátorka kvestor kvestorka kytarista láma laureát
laureátka lazar leader legionář lékař lektor lektorka lesák lesník lidovec
lídr likvidátor likvidátorka lingvista literát literátka lord loutkář lukostřelec majitel
majitelka major makléř makléřka malíř malířka máma maminka manažer manažerka manžel
manželka markýz maršál masér masérka matematik matematička matka mecenáš mecenáška medik medička meteorolog meteoroložka metropolita
miláček milenec milenka milionář milovník milovnice mim ministr ministryně
miss místopředseda místostarosta místostarostka mistr mistryně
mladík mladice mluvčí mnich mniška modelka moderátor moderátorka mořeplavec mučedník mučednice muslim muslimka
muž mužík muzikant muzikantka muzikolog muzikoložka myslitel myslivec náčelnice náčelník nacista
náhradnice náhradník nájemce nájemník nakladatel náměstek
námořník námořnice nástupce navrátilec návrhář návštěvník návštěvnice nestor neteř nositel
nositelka nováček novinář občan obchodník obchodnice obdivovatel obdivovatelka
obhájce objevitel objevitelka obránce obuvník obuvnice obyvatel obyvatelka ochránce odborář
odbornice odborník odchovanec operátor operátorka organizátor organizátorka ošetřovatel ošetřovatelka oštěpař
otec pamětník pamětnice pan pán paní panna papež partner partnerka pastýř pastýřka páter patriarcha
patron patronka pedagog pedagožka pekař perkusista pěvec pianista pilot pilotka písničkář
plavec playboy plukovník pochop podnikatel podnikatelka pokladník pokračovatel pokračovatelka
policajt policista politik politička politolog politoložka pomocník pomocnice pořadatel pořadatelka poradce poručík
poslanec posluchač posluchačka postava potomek poutník poutnice pověřenec
pozorovatel pozorovatelka pracovnice pracovník právník právnička pravnuk pravnučka předák předchůdce přednosta
předseda představitel představitelka překážkář překladatel
překladatelka premiér premiérka přemožitel přemožitelka prezident president prezidentka příbuzný
primář primátor primátorka princ princezna principál principálka příručí příslušník příslušnice
přítel příznivec prodavač prodavačka proděkan proděkanka producent
producentka profesionál profesionálka profesor profesorka programátor programátorka projektant projektantka prokurista prokuristka
proletář propagátor propagátorka prorok protagonista provozovatel provozovatelka
prozaik prozaička průkopník průkopnice průmyslník průvodce psychiatr psycholog psycholožka publicista
purkrabí rádce radikál radní redaktor redaktorka ředitel
ředitelka referent referentka rekordman rektor rektorka reportér reportérka reprezentant reprezentantka
republikán republikánka restaurátor restaurátorka režisér režisérka řezník řeznice řidič řidička rodák rodačka rodič rodička rolník rolnice
rozehrávač rozhodčí rybář rytíř šašek saxofonista sběratel sběratelka sbormistr sbormistryně
scenárista scénograf scénografka sedlák šéf šéfdirigent šéfdirigentka šéfka šéfkuchař
šéfredaktor šéfredaktorka šéftrenér sekretář semifinalista semifinalistka
senátor senátorka senior seniorka šerif seržant seržantka sestra sestřenice sexuolog sexuoložka signatář sir
skaut skautka skinhead skladatel skladatelka slávista slečna sluha služka smečař
sochař socialista sociolog socioložka sólista soudce soudruh soudružka
soukromník soukromnice soupeř soupeřka sourozenec soused sousedka specialista spisovatel
spisovatelka spojenec společník společnice spoluautor spoluautorka spoluhráč spoluhráčka spolujezdec
spolumajitel spolumajitelka spolupracovnice spolupracovník spolutvůrce spolužák spolužačka
spoluzakladatel spoluzakladatelka sponzor správce starosta starostka statkář státník stavbyvedoucí stavitel stavitelka
stoper stoupenec stratég strážce střelec strůjce strýc student studentka
stvořitel stvořitelka superhvězda surrealista švagr švagrová švec svědek syn synovec
tajemnice tajemník tanečnice tanečník táta tatínek tchán teatrolog teatroložka technik
technolog technoložka tenista tenor tenorista tenorsaxofonista teolog teoložka teoretik teoretička tesař
teta textař tlumočnice tlumočník továrník trenér trenérka trojskokan trojskokanka
trombonista truhlář trumpetista tvůrce účastnice účastník učenec účetní
učitel učitelka uhlíř uklízečka umělec uprchlík uprchlice úřednice úředník
útočník útočnice varhaník varhanice vdova vdovec vědec vedoucí velitel velitelka velmistr velmistryně velvyslanec
verbíř veterán veteránka vévoda vězeň vibrafonista viceguvernér viceguvernérka vicemistr vicemistryně
vicepremiér vicepremiérka viceprezident viceprezidentka violista violoncellista vítěz vítězka
vladyka vlastník vlastnice vnuk vnučka voják vrah vrátný vrstevník vůdce výčepní vychovatel vychovatelka
vydavatel vyjednavač vynálezce výrobce vyšetřovatel vyšetřovatelka vyslanec výtvarnice
výtvarník vyznavač vyznavačka zahradník zahradnice žák zakladatel zakladatelka
záložník záložnice zámečník zámečnice zaměstnanec zapisovatel zapisovatelka zastánce zástupce
závodník zedník železničář zemědělec žena žid židovka živnostník živnostnice
zločinec zloděj zmocněnec znalec známý zoolog zpěvák zpěvačka zplnomocněnec
