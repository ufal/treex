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
aktivista aktivistka amatér analytička analytik anděl archeolog archeoložka architekt architektka arcibiskup
asistent asistentka astronom atlet auditor auditorka automechanik autor autorka baba babička
banjista bankéř bankéřka baron baronka barytonista basista basketbalista basketbalistka baskytarista baskytaristka básník
básnířka běžec běžkyně bibliofil biochemik biolog bioložka biskup blokařka bohemista bohemistka
bojovník bojovnice botanik botanička boxer brácha brankář brankářka bratr bratranec bratříček bubeník bubenice
budovatel budovatelka car čaroděj čarodějka cellista cellistka černoch černoška cestovatel cestovatelka chargé chemik chirurg
chlap chlapec choreograf choreografka choť chudák činovník činovnice císař číšník číšnice
cizinec cizinka člen členka člověk čtenář čtenářka cvičitelka cyklista cyklistka dáma dcera
dealer dědeček dědic dědička dějepisec děkan děkanka delegát delgátka dělník dělnice desetibojař desetibojařka
diplomat dirigent dirigentka divadelník divedelnice divák divačka dívka dobrodruh docent docentka dodavatel dodavatelka doktor
doktorka dopisovatel dopisovatelka dozorce dozorkyně dramatička dramatik dramaturg dramaturgyně držitel
držitelka důchodce důchodkyně důstojník důstojnice ekolog ekonom
ekonomka elektrotechnik emigrant epidemiolog epidemioložka estetik etnograf etnolog exmanžel exmanželka
exministr expert expertka expremiér farář farářka farmář farmářka favorit filolog filoložka
filozof filosof filozofka finalista finalistka flétnista fořt fotbalista fotbalistka fotograf fotografka
frontman funkcionář funkcionářka fyzik garant garantka generál generálmajor génius geograf geografka geolog geoložka
gólman grafik grafička guvernér guvernérka gynekolog gynekoložka harfenistka herec herečka historička historik hlasatel hlasatelka
hoch hokejista hokejistka horník horolezec horolezkyně hospodář hospodářka hospodyně host hostinský hostinská houslista
houslistka hrabě hraběnka hráč hráčka hrdina hrdinka hudebník hudebnice hygienik hygienička
idol ikona ilustrátor ilustrátorka imitátor imitátorka iniciátor iniciátorka inspektor inspektorka instalatér internista internistka investor investorka
inženýr inženýrka jednatel jednatelka jezdec jezdkyně jinoch kacíř kacířka kadeřnice kamarád kamarádka kamelot
kameník kameraman kameramanka kancléř kancléřka kandidát kandidátka kanoista kanoistka kanonýr
kapelník kapelnice kapitán kapitánka kaplan kardinál kardiolog kardioložka kat keramik keramička kladivář klasik klávesista klávesistka
klavírista klavíristka kluk kněz kněžna knihovník knihovnice kočí kolega kolegyně
komentátor komentátorka komik kominice komisař komisařka komisionář komorník komornice komunista komunistka konstruktér konstruktérka
kontrabasista kontrabasistka konzultant konzultantka koordinátor koordinátorka koproducent koproducentka kosmonaut kosmonautka kostelník kostelnice
kouč koučka koulař koulařka kovář kovářka krajkářka král královna krejčí kreslíř kreslířka křesťan křesťanka
kritik kritička kuchař kuchařka kulak kurátor kurátorka kvestor kvestorka kytarista kytaristla láma laureát
laureátka lazar leader legionář legionářka lékař lékařka lektor lektorka lesák lesník lidovec
lídr likvidátor likvidátorka lingvista lingvistka literát literátka lord loutkář lukostřelec lukostřelkyně majitel
majitelka major makléř makléřka malíř malířka máma maminka manažer manažerka manžel
manželka markýz maršál masér masérka matematik matematička matka mecenáš mecenáška medik medička meteorolog meteoroložka metropolita
mezzosopranistka miláček milenec milenka milionář milionářka milovník milovnice mim ministr ministryně
miss místopředseda místopředsedkyně místostarosta místostarostka mistr mistryně
mladík mladice mluvčí mnich mniška modelka moderátor moderátorka mořeplavec mučedník mučednice muslim muslimka
muž mužík muzikant muzikantka muzikolog muzikoložka myslitel myslivec náčelnice náčelník nacista nacistka
náhradnice náhradník nájemce nájemník nakladatel náměstek náměstkyně
námořník námořnice nástupce nástupkyně navrátilec návrhář návrhářka návštěvník návštěvnice nestor neteř nositel
nositelka nováček novinář novinářka občan obchodník obchodnice obdivovatel obdivovatelka
oběť obhájce obhájkyně objevitel objevitelka obránce obránkyně obuvník obuvnice obyvatel obyvatelka ochránce ochránkyně odborář odborářka
odbornice odborník odchovanec organizátor organizátorka ošetřovatel ošetřovatelka osobnost oštěpař oštěpařka
otec pamětník pamětnice pan pán paní panna papež partner partnerka pastýř pastýřka páter patriarcha
patron patronka pedagog pedagožka pekař pekařka perkusista perkusistka pěvec pěvkyně pianista pianistka pilot pilotka písničkář písničkářka
plavec plavkyně playboy plukovník pochop podnikatel podnikatelka pokladník pokračovatel pokračovatelka
policajt policista policistka politik politička politolog politoložka pomocník pomocnice pořadatel pořadatelka poradce poradkyně poručík
poslanec poslankyně posluchač posluchačka postava potomek poutník poutnice pověřenec pověřenkyně
pozorovatel pozorovatelka pracovnice pracovník právník právnička pravnuk pravnučka předák předchůdce předchůdkyně přednosta
předseda předsedkyně představitel představitelka překážkář překladatel
překladatelka premiér premiérka přemožitel přemožitelka prezident president prezidentka příbuzný
primář primářka primátor primátorka princ princezna principál principálka příručí příslušník příslušnice
přítel přítelkyně příznivec příznivkyně prodavač prodavačka proděkan proděkanka producent
producentka profesionál profesionálka profesor profesorka programátor programátorka projektant projektantka prokurista prokuristka
proletář proletářka propagátor propagátorka prorok protagonista protagonistka provozovatel provozovatelka
prozaik prozaička průkopník průkopnice průmyslník průvodce průvodkyně psychiatr psycholog psycholožka publicista
publicistka purkrabí rádce rádkyně radikál radní redaktor redaktorka ředitel
ředitelka referent referentka rekordman rektor rektorka reportér reportérka reprezentant reprezentantka
republikán republikánka restaurátor restaurátorka režisér režisérka řezník řeznice řidič řidička rodák rodič rolník rolnice
rozehrávač rozhodčí rybář rybářka rytíř šašek saxofonista saxofonistka sběratel sběratelka sbormistr sbormistryně
scenárista scenáristka scénograf scénografka sedlák šéf šéfdirigent šéfdirigentka šéfka šéfkuchař šéfkuchařka
šéfredaktor šéfredaktorka šéftrenér sekretář sekretářka semifinalista semifinalistka
senátor senátorka šerif seržant seržantka sestra sestřenice sexuolog sexuoložka signatář signatářka sir
skaut skautka skinhead skladatel skladatelka slávista slávistka slečna sluha služka smečař smečařka
sochař sochařka socialista socialistka sociolog socioložka sólista sólistka sopranistka soudce soudkyně soudruh soudružka
soukromník soukromnice soupeř soupeřka sourozenec soused sousedka specialista specialistka spisovatel
spisovatelka spojenec spojenkyně společník společnice spoluautor spoluautorka spoluhráč spoluhráčka spolujezdec spolujezdkyně
spolumajitel spolumajitelka spolupracovnice spolupracovník spolutvůrce spolužák spolužačka
spoluzakladatel spoluzakladatelka sponzor správce správkyně starosta starostka statkář statkářka státník stavbyvedoucí stavitel stavitelka
stoper stoupenec stoupenkyně stratég strážce strážkyně střelec střelkyně strůjce strůjkyně strýc student studentka
stvořitel stvořitelka superhvězda surrealista surrealistka švagr švagrová švec svědek svědkyně syn synovec
tajemnice tajemník tanečnice tanečník táta tatínek tchán teatrolog teatroložka technik
technolog technoložka tenista tenistka tenor tenorista tenorsaxofonista tenorsaxofonistka teolog teoložka teoretik teoretička tesař
teta textař textařka tlumočnice tlumočník továrník trenér trenérka trojskokan trojskokanka
trombonista trombonistka truhlář truhlářka trumpetista trumpetistka tvůrce tvůrkyně účastnice účastník učenec učenkyně účetní
učitel učitelka uhlíř uklízečka umělec umělkyně uprchlík uprchlice úřednice úředník
útočník útočnice varhaník varhanice vdova vdovec vědec vědkyně vedoucí velitel velitelka velmistr velmistryně velvyslanec velvyslankyně
verbíř veterán veteránka vévoda vévodkyně vězeň vězeňkyně vibrafonista vibrafonistka viceguvernér viceguvernérka vicemistr vicemistryně
vicepremiér vicepremiérka viceprezident viceprezidentka violista violistka violoncellista violoncellistka vítěz vítězka
vladyka vlastník vlastnice vnuk vnučka voják vrah vrátný vrstevník vůdce vůdkyně výčepní vychovatel vychovatelka
vydavatel vyjednavač vynálezce vynálezkyně výrobce vyšetřovatel vyšetřovatelka vyslanec vyslankyně výtvarnice
výtvarník vyznavač vyznavačka zahradník zahradnice žák zakladatel zakladatelka žákyně
záložník záložnice zámečník zámečnice zaměstnanec zaměstnankyně zapisovatel zapisovatelka zastánce zástupce
zástupkyně závodník zedník železničář zemědělec žena žid židovka živnostník živnostnice
zločinec zloděj zmocněnec zmocněnkyně znalec znalkyně známý zoolog zpěvák zpěvačka zplnomocněnec zplnomocněnkyně
