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

abbé absolvent absolventka adresa advokát advokátka agent agentura akademik
aktivista amatér analytička analytik anděl archeolog architekt arcibiskup asistence
asistent asistentka astronom atlet auditor automechanik autor autorka baba babička
banjista banka bankéř baron barytonista basista basketbalista baskytarista básník
básnířka beran běžec bibliofil biochemik biolog biskup blokařka bohemista
bojovník botanik boxer brácha branka brankář bratr bratranec bratříček bubeník
budovatel car čaroděj cellista černoch cestovatel chargé chemik chirurg
chirurgie chlap chlapec choreograf choť chudák činovník císař číšník
cizinec člen členka člověk čtenář čtyřhra cvičitelka cyklista dáma dcera
dealer dědeček dědic dědička dějepisec děkan delegát dělník desetibojař
diplomat dirigent divadelník divák dívka dobrodruh docent dodavatel dohoda doktor
doktorka dopisovatel dozorce dramatička dramatik dramaturg dramaturgyně držitel
držitelka důchodce důchodkyně důstojník dvojice edice editor ekolog ekonom
ekonomka elektrotechnik emigrant epidemiolog estetik etnograf etnolog exmanželka
exministr expert expozice expremiér farář farářka farmář favorit filolog
filozof finalista finalistka flétnista fořt fotbalista fotograf fotografka
frontman funkcionář fyzik garant generál generálmajor génius geograf geolog
gólman grafik guvernér gynekolog harfenistka herec historička historik hlasatel
hlava hoch hokejista horník horolezec hospodář hospodyně host hostinský houslista
houslistka hraběnka hráč hráčka hrdina hrdinka hudebník hvězda hygienik
idol ikona ilustrátor imitátor iniciátor inspektor instalatér internista investor
inženýr jednatel jednatelka jezdec jinoch kacíř kadeřnice kamarád kamelot
kameník kamera kameraman kancelář kancléř kandidát kandidátka kanoista kanonýr
kapelník kapitán kaplan kardinál kardiolog kat keramik kladivář klasik klávesista
klavírista klavíristka kluk kněz kněžna knihovník kočí kolega kolegyně
komentátor komik komisař komisařka komisionář komorník komunista konstruktér
kontrabasista konzultant koordinátor koordinátorka koproducent kosmonaut kostelník
kouč koulař kovář krajina krajkářka král královna krejčí kreslíř křesťan
kritik kuchař kuchařka kulak kurátor kurátorka kvestor kytarista láma laureát
laureátka lazar leader legionář lékař lékařka lektor lesák lesník lidovec
lídr likvidátor lingvista literát literatura lord loutkář lukostřelec majitel
majitelka major makléř malíř malířka máma maminka manažer manažerka manžel
manželka markýz maršál masér matematik matka mecenáš medik meteorolog metropolita
mezzosopranistka miláček milenec milenka milionář milovník mim ministr ministryně
miss místopředseda místopředsedkyně místostarosta místostarostka mistr mistryně
mladík mluvčí mnich modelka moderátor moderátorka mořeplavec mučedník muslim
muž mužík muzikant muzikolog myslitel myslivec náčelnice náčelník nacista
nadace náhradnice náhradník nájemce nájemník nakladatel náměstek náměstkyně
námořník nástupce navrátilec návrhář návštěvník nestor neteř nositel
nositelka nováček novinář novinářka novinka občan obchodník obdivovatel
oběť obhájce obhájkyně objevitel obránce obuvník obyvatel ochránce odborář
odbornice odborník odchovanec operace organizátor ošetřovatelka osobnost oštěpař
otec pamětník pan pán paní panna papež papoušek partner pastýř páter patriarcha
patron pedagog pekař perkusista pěvec pěvkyně pianista pilot písničkář
plavkyně playboy plukovník pochop podnikatel podnikatelka pokladník pokračovatel
policajt policista politik politolog pomocník pořadatel poradce poradkyně poručík
poslanec poslankyně posluchač posluchačka postava potomek poutník pověřenec
pozorovatel pracovnice pracovník právník pravnuk předák předchůdce přednosta
předseda předsedkyně představitel představitelka překážkář překladatel
překladatelka premiér přemožitel prezident prezident prezidentka příbuzný
primář primářka primátor princ princezna principál příručí příslušník
přítel privatizace příznivec prodavač prodavačka prodejna proděkan producent
producentka profesionál profesor profesorka programátor projektant prokurista
proletář propagátor prorok protagonista protagonistka provozovatel provozovatelka
prozaik průkopník průmyslník průvodce průvodkyně psychiatr psycholog publicista
publicistka purkrabí rada rádce radikál radní radnice redaktor redaktorka ředitel
ředitelka referent referentka rekordman rektor reportér reprezentant reprezentantka
republikán restaurátor režisér režisérka řezník řidič rodák rodič rolník
rozehrávač rozhodčí rybář rytíř šašek saxofonista sběratel sbormistr
scenárista scenáristka scénograf sedlák šéf šéfdirigent šéfka šéfkuchař
šéfredaktor šéfredaktorka šéftrenér sekretář sekretářka semifinalistka
senátor senátorka šerif seržant sestra sestřenice sexuolog signatář sir
skaut skinhead skladatel skladba skupina slávista slečna sluha smečařka sněmovna
sochař sochařka socialista sociolog sólista sólistka sopranistka soudce soudruh
soukromník soupeř sourozenec soused soutěž specialista specialistka spisovatel
spisovatelka spojenec spojka společník spoluautor spoluautorka spoluhráč spolujezdec
spolumajitel spolumajitelka spolupracovnice spolupracovník spolutvůrce spolužák
spoluzakladatel sponzor správce starosta statkář státník stavbyvedoucí stavitel
stoper stoupenec stratég strážce střelec strůjce strýc student studentka
stvořitel superhvězda surrealista švagr švec svědek svoboda symfonie syn synovec
tajemnice tajemník tanečnice tanečník táta tatínek tchán teatrolog technik
technolog tenista tenistka tenor tenorista tenorsaxofonista teolog teoretik tesař
teta textař tlumočnice tlumočník továrník trenér trenérka trojskokanka
trombonista truhlář trumpetista tvůrce účastnice účastník učenec účetní
učitel učitelka uhlíř uklízečka umělec úprava uprchlík úřednice úředník
útočník varhaník vdova vědec vedoucí velitel velmistr velvyslanec velvyslankyně
verbíř veterán veteránka vévoda vězeň vibrafonista viceguvernér vicemistr
vicepremiér viceprezident viceprezidentka violista violoncellista vítěz vítězka
vladyka vlastník vnuk voják vrah vrátný vrstevník vůdce výčepní vychovatelka
vydavatel vyjednavač vynálezce výrobce vyšetřovatel vyslanec výstava výtvarnice
výtvarník vyznavač vzpoura zahradník žák zakladatel zakladatelka žákyně
záložník zámečník zaměstnanec zapisovatel zapisovatelka zastánce zástupce
zástupkyně závodník zedník železničář zemědělec žena žid živnostník
zločinec zloděj zmocněnec znalec známý zoolog zpěvák zplnomocněnec
