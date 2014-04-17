package Treex::Block::A2T::SK::SetPhrasalFunctors;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

#
# Dictionaries of light verb and phraseme constructions.
# generated automatically from SloVallex, see SloVallex SVN (cphr_dphr subdirectory)
# for the code that generated this.
#

my %CPHR = (
    'brať' => [
        ['(ohľad|zreteľ)'],
        ['(podiel)'],
        ['(právo|právo)'],
    ],
    'byť' => [
        ['treba'],
        ['potreba'],
        ['potreba'],
        ['škoda'],
        ['(nutný|možný|vhodný)'],
        ['(ťažko|ťažko|zaťažko)'],
        ['(hanblivo)'],
        ['(hanba|hanba)'],
        ['jeden'],
        ['(ľúto)'],
    ],
    'bývať' => [
        ['(ľúto|hanblivo|hanba|jeden|hanba)'],
        ['(treba|potreba)'],
        ['(nutný|možný|zaťažko|zaťažko)'],
    ],
    'chovať' => [
        ['(dôvera|podozrenie|nenávisť|nádej|priateľstvo|cit)'],
    ],
    'cítiť' => [
        ['(potreba|nutkanie)'],
    ],
    'dať' => [
        ['(zaucho|facka|bránka|gól|rana)'],
        ['(poverenie|podpora|súhlas|správa|impulz|odpoveď|možnosť|príkaz|nádej|popud|príčina|právo|príležitosť|signál|šanca)'],
        ['(prednosť|preferencia)'],
        ['(hlas)'],
        ['(dôkaz|informácia|návrh|oznámenie|podnet|sťažnosť|záruka|správa|žiadosť|žaloba)'],
        ['(pečať)'],
        ['(priestor|možnosť|nádej|popud|právo|príležitosť|šanca)'],
        ['(dôkaz|informácia|návrh|oznámenie|podnet|sťažnosť|správa|žiadosť|žaloba)'],
        ['(dôkaz|informácia|návrh|oznámenie|podnet|sťažnosť|správa|žiadosť|žaloba)'],
        ['(pokuta|sankcia)'],
        ['(dôraz)'],
    ],
    'dať sa' => [
        [ 'do', '(práca|výroba|hospodárenie|výklad|let|pohyb)' ],
        [ 'v',  '(let)' ],
    ],
    'dostať' => [
        ['(šanca|výpoveď|odškodnenie|priestor|doporučenie|informácia|impulz|možnosť|ponuka|návrh|odpoveď|povolenie|pokuta|prednosť|príležitosť|prísľub|prístup|rada|sľub|súhlas|uistenie|rozkaz|úkol|zákaz|správa)'],
        ['(chuť|nápad)'],
    ],
    'dostávať' => [
        ['(priestor|doporučenie|impulz|možnosť|ponuka|návrh|odpoveď|povolenie|pokuta|prednosť|príležitosť|prísľub|prístup|sľub|súhlas|uistenie|rozkaz|úkol|zákaz|správa)'],
    ],
    'dávať' => [
        ['(priestor|poverenie|podpora|impulz|možnosť|príkaz|nádej|popud|príčina|právo|príležitosť|signál|šanca)'],
        ['(prednosť|preferencia)'],
        ['(dôkaz|informácia|návrh|oznámenie|podnet|sťažnosť|správa|žiadosť|žaloba)'],
        ['(dôraz)'],
        ['(pokuta|sankcia|výpoveď)'],
        ['(dôkaz|informácia|návrh|oznámenie|podnet|sťažnosť|správa|žiadosť|žaloba)'],
        ['(dôkaz|informácia|návrh|oznámenie|podnet|sťažnosť|správa|žiadosť|žaloba)'],
        ['(zaucho|facka)'],
    ],
    'dávať sa' => [
        [ 'do', '(pohyb|práca|pochod|výroba|hospodárenie|výklad)' ],
    ],
    'horieť' => [
        ['(nenávisť|túžba)'],
    ],
    'javiť' => [
        ['(záujem|tendencia)'],
    ],
    'klásť' => [
        ['(otázka|otázka)'],
        ['(dôraz)'],
        ['(nárok|požiadavka)'],
        ['(odpor|podmienka|prekážka|cieľ|medza)'],
    ],
    'mať' => [
        ['(dlh|oprávnenie|túžba|úloha|záväzok|sila|pochybnosť|predstava|cieľ|čas|česť|chuť|mechanizmus|možnosť|nádej|pocit|potreba|povinnosť|odvaha|právo|právomoc|schopnosť|sklon|snaha|šanca|tušenie|zámer)'],
        ['potreba'],
        ['(záujem)'],
        ['(problém|problém)'],
        ['(dopad|nárok|účinok|vplyv)'],
        ['(obava|potešenie|strach|radosť|dojem)'],
        ['(predpoklad|sklon|tendencia|plán|šanca)'],
        ['(priestor|dôvod|motivácia|príležitosť)'],
        ['(zmysel|význam|cena)'],
        ['(oneskorenie|skúsenosť)'],
        ['(podiel|zásluha)'],
        ['(námietka|výhrada|nič|niečo)'],
        ['(námietka|výhrada|nič|niečo)'],
        ['(nedôvera|prednosť|rešpekt|náskok|dôvera)'],
        ['(názor|mienka)'],
        ['(následok|dôsledok)'],
        ['(vzťah)'],
        ['(prevaha)'],
        ['(povolenie|zvolenie|súhlas)'],
        ['(rešpekt|dôvera)'],
        ['(pripomienka|poznámka|návrh)'],
        ['(záruka)'],
        ['(styk)'],
        ['(dozor|dohľad)'],
    ],
    'mávať' => [
        ['(predstava|spomienka|vzpomienka|pocit)'],
        ['(podiel|zásluha)'],
        ['(pripomienka|poznámka)'],
        ['(dopad|vplyv)'],
        ['(prednosť|rešpekt|náskok)'],
        ['(čas|česť|chuť|možnosť|nádej|potreba|povinnosť|povolenie|právo|právomoc|schopnosť|snaha|šanca)'],
        ['(zmysel|význam|cena)'],
        ['(predpoklad|sklon|tendencia)'],
        ['(obava|potešenie|strach)'],
        ['(problém|problém|porucha)'],
        ['(dôvod|motivácia|príležitosť)'],
        ['(záujem)'],
        ['(dôvera|vzťah)'],
    ],
    'nachádzať' => [
        ['(odvaha|potešenie|východisko|riešenie|uplatnenie)'],
    ],
    'nadobudnúť' => [
        ['(dojem|presvedčenie)'],
        ['(dojem)'],
    ],
    'nadväzovať' => [
        ['(dialóg|kontakt|zmluva|spojenie|spolupráca|styk|vzťah)'],
    ],
    'naskytnúť sa' => [
        ['(možnosť|výhľad)'],
        ['(pohľad|možnosť|výhľad)'],
    ],
    'naviazať' => [
        ['(dialóg|kontakt|zmluva|spojenie|spolupráca|styk|vzťah)'],
    ],
    'navodiť' => [
        ['(dojem|nostalgia|pocit|pohoršenie|túžba)'],
    ],
    'navodzovať' => [
        ['(dojem|nostalgia|pocit|pohoršenie|túžba|atmosféra|myšlienka|predstava)'],
    ],
    'nazbierať' => [
        ['(odvaha|skúsenosť|poznatok)'],
    ],
    'niesť' => [
        ['(zodpovednosť|strata|zodpovednosť|vina|riziko|dôsledok|následok|miera|spoluvina)'],
    ],
    'nájsť' => [
        ['(možnosť|odvaha|potešenie|riešenie|východisko|uplatnenie)'],
        ['(možnosť|odvaha|odpoveď|potešenie|riešenie|východisko|uplatnenie)'],
    ],
    'náležať' => [
        ['(oprávnenie|právo)'],
    ],
    'obracať' => [
        ['(pozornosť)'],
    ],
    'obrátiť' => [
        ['(pozornosť)'],
    ],
    'obstarať,poriadiť' => [
        ['(zápis|záznam)'],
    ],
    'obstarávať,poriaďovať' => [
        ['(kópia|zápis|záznam)'],
    ],
    'otvoriť' => [
        ['(možnosť|prístup|cesta|priestor)'],
    ],
    'otvárať' => [
        ['(možnosť|prístup|priestor|cesta)'],
        ['(možnosť|priestor|prístup|čo)'],
    ],
    'padnúť' => [
        ['(slovo|zmienka|rozhodnutie|otázka|poznámka|návrh)'],
    ],
    'planúť' => [
        ['(nenávisť|túžba)'],
    ],
    'pociťovať' => [
        ['(potreba)'],
    ],
    'pocítiť' => [
        ['(potreba)'],
    ],
    'podať' => [
        ['(odvolanie|vysvetlenie|protest|dôkaz|informácia|návod|návrh|obžaloba|podnet|pokyn|sťažnosť|výpoveď|správa|žiadosť|žaloba)'],
        ['(výkon)'],
        ['(demisia|odvolanie)'],
        ['(dôkaz|informácia|návrh|odvolanie|podnet|sťažnosť|výpoveď|správa|žiadosť|žaloba)'],
        ['(obžaloba|dôkaz|informácia|návrh|podnet|protest|sťažnosť|výpoveď|správa|žiadosť|žaloba)'],
    ],
    'podnikať' => [
        ['(krok|opatrenie)'],
    ],
    'podniknúť' => [
        ['(krok|opatrenie)'],
        ['(obsadenie|invázia|útok|zájazd)'],
    ],
    'podávať' => [
        ['(odvolanie|protest|dôkaz|informácia|návrh|návod|podnet|sťažnosť|svedectvo|správa|žiadosť|žaloba)'],
        ['(výkon)'],
        ['(protest|dôkaz|informácia|návrh|podnet|sťažnosť|správa|žiadosť|žaloba)'],
        ['(protest|dôkaz|informácia|návrh|sťažnosť|správa|žiadosť|žaloba)'],
    ],
    'pojať' => [
        ['(podozrenie)'],
    ],
    'pokladať' => [
        ['(otázka|dotaz|otázka)'],
        ['(dôraz)'],
    ],
    'položiť' => [
        ['(otázka|dotaz|otázka)'],
        ['(dôraz|dôraz)'],
    ],
    'popadnúť' => [
        ['(...)'],
    ],
    'poskytnúť' => [
        ['(rozhovor|výchova|ubytovanie|dotácia|kompenzácia|pôžička|garancia|informácia|možnosť|ochrana|pomoc|podpora|záruka|rada|služba)'],
    ],
    'poskytovať' => [
        ['(dotácia|informácia|príspevok|starosť|opatera|činnosť|možnosť|ochrana|podpora|pomoc|záruka|rada|služba|pôžička|zľava)'],
    ],
    'pozberať,pozbierať' => [
        ['(vedomosť|odvaha|skúsenosť)'],
    ],
    'prebúdzať' => [
        ['(dojem|nostalgia|pocit|túžba|záujem)'],
    ],
    'predať' => [
        ['(informácia|podnet|správa)'],
        ['(informácia|podnet|správa)'],
    ],
    'predávať' => [
        ['(informácia|podnet|správa)'],
        ['(informácia|podnet|správa)'],
    ],
    'prejaviť' => [
        ['(nezáujem|nesúhlas|záujem|ľútosť|nadšenie|prianie|názor)'],
        ['(nedôvera|dôvera|sústrasť|úcta|uznanie)'],
    ],
    'prejavovať' => [
        ['(nesúhlas|záujem|ľútosť|nadšenie|prianie)'],
        ['(dôvera|sústrasť|úcta|uznanie)'],
    ],
    'prevádzať,vykonávať' => [
        ['(odber|aktualizácia|farbenie|dozor|inštruktáž|prieskum|reorganizácia|reštrukturalizácia|úkon|údržba|úprava|test|vklad|hodnotenie|zmena)'],
        ['(debata|dialóg|rozhovor|hovor)'],
        ['(operácia)'],
    ],
    'prichádzať' => [
        [ 'do', '(styk|kontakt)' ],
        [ 's',  '(nápad|návrh|opatrenie)' ],
        [ 'o',  '(možnosť|právo|ilúzia)' ],
        [ 'na', '(nápad|riešenie)' ],
    ],
    'prijať' => [
        ['(rozhodnutie|opatrenie|uznesenie|záver)'],
    ],
    'prijímať' => [
        ['(rozhodnutie|opatrenie|riešenie)'],
    ],
    'pristupovať' => [
        [ 'k', '(hlasovanie|realizácia|plán|udelenie|zmena|obnova|modernizácia)' ],
    ],
    'pristúpiť' => [
        [ 'k', '(použitie|stimulácia|likvidácia|jednanie|riešenie|premena|hlasovanie|kontrola|krok|realizácia|plán|udelenie|zmena|uťahovanie)' ],
    ],
    'príslušať' => [
        ['(oprávnenie|právo)'],
    ],
    'prísť' => [
        [ 's',  '(tvrdenie|nápad|návrh|myšlienka|požiadavka|riešenie)' ],
        [ 'do', '(styk|kontakt)' ],
        [ 'o',  '(výhoda|možnosť|právo|ilúzia)' ],
        [ 'na', '(nápad|riešenie)' ],
    ],
    'robiť' => [
        ['(rozhovor|práca|prognóza|sľub|test|chyba|inštruktáž|obhliadka|propagácia|prieskum|reorganizácia|reštrukturalizácia|údržba|ústupok|vklad|hodnotenie|pokus|krok|opatrenie|pokrok|expertíza|kontrola|obmedzenie|vyšetrenie|záťah)'],
        ['(záver)'],
        ['(dojem)'],
    ],
    'skytať' => [
        ['(možnosť|pomoc|záruka|rada|služba)'],
    ],
    'spriadať' => [
        ['(plán|úvaha)'],
    ],
    'stavať' => [
        ['(bariéra|prekážka)'],
        ['otázka'],
    ],
    'stratiť' => [
        ['(nádej|odvaha|zmysel)'],
        ['(nádej|odvaha|zmysel)'],
        ['(chuť|možnosť|príležitosť)'],
    ],
    'strácať' => [
        ['(nádej|odvaha|zmysel)'],
        ['(nádej|odvaha|zmysel)'],
    ],
    'ucítiť' => [
        ['(potreba)'],
    ],
    'udeliť' => [
        ['(cena|pochvala|pokuta|rada|súhlas|uznanie)'],
    ],
    'udeľovať' => [
        ['(autorizácia|cena|trest|pochvala|pokuta|rada|súhlas|uznanie|titul|zmocnenie)'],
    ],
    'ukladať' => [
        ['(trest|povinnosť|pokuta|sankcia|penále|úkol)'],
    ],
    'uložiť' => [
        ['(trest|povinnosť|pokuta|sankcia)'],
    ],
    'uprieť' => [
        ['(pozornosť|zrak)'],
    ],
    'urobiť' => [
        ['(rozhodnutie|škrt|výber|ústupok|pokus|krok|chyba|opatrenie|pokrok|expertíza|kontrola|obmedzenie|výskum|záťah)'],
        ['(koniec)'],
        ['(dojem)'],
        ['(záver)'],
        ['(zápis|záznam)'],
    ],
    'uvaliť' => [
        ['(blokáda|clo|daň|embargo|exekúcia|hypotéka|karanténa|sankcia|väzba)'],
    ],
    'uzavierať,uzatvárať' => [
        ['(dohoda|kompromis|kontrakt|zmluva|prímerie|stávka)'],
    ],
    'uzavrieť' => [
        ['(partnerstvo|vzťah|dohoda|obchod|kontrakt|zmluva|zmier|sobáš|mier|prímerie|stávka|účet)'],
    ],
    'učiniť' => [
        ['(rozhodnutie|prehlásenie|previerka|expertíza|kontrola|obmedzenie|oznámenie|záťah|pokus|krok|opatrenie|pokrok)'],
        ['(ústupok|ponuka)'],
        ['(záver|zhrnutie)'],
        ['(koniec)'],
        ['(dojem)'],
    ],
    'venovať' => [
        ['(pozornosť|čas|záujem|priestor|starosť|opatera|priazeň|lojalita)'],
    ],
    'viesť' => [
        ['(kampaň|riadenie|útok|operácia|komunikácia|pohovor|boj|debata|dialóg|diskusia|jednanie|polemika|propaganda|rozhovor|hovor|spor|tiahnutie|vojna|vyjednávanie)'],
        ['(žaloba)'],
    ],
    'vojsť' => [
        [ 'v',  '(platnosť|povedomie|styk)' ],
        [ 'do', '(platnosť|povedomie|styk)' ],
    ],
    'vrhať' => [
        ['(tieň|podozrenie|svetlo)'],
    ],
    'vrhnúť' => [
        ['(tieň|podozrenie|svetlo)'],
    ],
    'vstupovať' => [
        [ 'v', '(platnosť)' ],
    ],
    'vstúpiť' => [
        [ 'v', '(platnosť)' ],
    ],
    'vycítiť' => [
        ['(potreba)'],
    ],
    'vydať' => [
        ['(zákaz|pokyn|rozkaz|súhlas|príkaz)'],
    ],
    'vydávať' => [
        ['(pokyn|rozkaz|súhlas|príkaz|povolenie)'],
    ],
    'vyhlasovať' => [
        ['(boj|vojna|preferencia)'],
    ],
    'vyhlásiť' => [
        ['(boj|vojna)'],
    ],
    'vyjadriť' => [
        ['(prianie|údiv|obdiv|sklamanie|obava|súhlas|ochota|uspokojenie|nádej|prekvapenie|spokojnosť|hodnotenie|pripravenosť|podozrenie|úzkosť|stanovisko|pochyba|protest|záujem|vôľa|pochopenie|postoj|názor)'],
        ['(vďaka|dôvera|sústrasť|úcta|uznanie|podpora|sympatia|preferencia)'],
    ],
    'vyjadrovať' => [
        ['(údiv|obdiv|sklamanie|obava|súhlas|ochota|uspokojenie|nádej|prekvapenie|spokojnosť|hodnotenie|pripravenosť|podozrenie|úzkosť|stanovisko|pochyba|protest|záujem|vôľa|pochopenie|postoj|názor)'],
        ['(dôvera|sústrasť|úcta|uznanie|podpora|sympatia|preferencia)'],
    ],
    'vykonať' => [
        ['(dozor|uzdravovanie|skutok|čin|pokus|príprava|práca|pozorovanie)'],
        ['(poradenstvo|správa|návšteva|sľub|test|inštruktáž|prieskum|reorganizácia|reštrukturalizácia|údržba|vklad|hodnotenie)'],
    ],
    'vykonať,previesť' => [
        ['(rozbor|vyšetrenie|aktualizácia|inštruktáž|prieskum|reorganizácia|reštrukturalizácia|údržba|test|vklad|hodnotenie|zmena|znárodnenie)'],
        ['(operácia)'],
        ['(debata|dialóg|rozhovor|hovor)'],
    ],
    'vykonávať' => [
        ['(práca|dozor|služba|činnosť|sľub|inventarizácia|test|inštruktáž|prieskum|reorganizácia|reštrukturalizácia|údržba|vklad|hodnotenie)'],
    ],
    'vyniesť' => [
        ['(súd|rozsudok|trest)'],
    ],
    'vypovedať' => [
        ['(vojna)'],
    ],
    'vysloviť' => [
        ['(nesúhlas|námietka|informácia|názor|súhlas|spokojnosť|prianie|uspokojenie|ľútosť|hypotéza|predpoklad|verdikt|idea|myšlienka|podozrenie|domnienka|požiadavka|obava|potreba|predpoveď)'],
        ['(dôvera|nedôvera|podpora|kompliment)'],
    ],
    'vyslovovať' => [
        ['(nesúhlas|názor|súhlas|spokojnosť|prianie|uspokojenie|ľútosť|predpoklad|verdikt|idea|myšlienka|podozrenie|domnienka|požiadavka|obava|potreba|predpoveď)'],
        ['(dôvera|nedôvera|podpora|kompliment)'],
    ],
    'vytvoriť' => [
        ['(zápis|záznam)'],
    ],
    'vyvinúť' => [
        ['(činnosť|nátlak|tlak|snaha|úsilie)'],
    ],
    'vyvolať' => [
        ['(neistota|protest|rozpaky|dohad|dojem|dôvera|nálada|nadšenie|požiadavka|napätie|nedôvera|nevôľa|odpor|panika|prejav|reakcia|snaha|záujem|zmätok)'],
    ],
    'vyvolávať' => [
        ['(protest|rozpaky|údiv|spomienka|vzpomienka|dohad|dojem|dôvera|nadšenie|napätie|nedôvera|nevôľa|odpor|panika|prejav|reakcia|snaha|záujem|zmätok)'],
    ],
    'vyvíjať' => [
        ['(nátlak|tlak|snaha|činnosť)'],
    ],
    'vzbudiť' => [
        ['(dojem|nostalgia|pocit|pohoršenie|pozornosť|rozpaky|závisť|zdanie)'],
    ],
    'vzbudiť,zobudiť' => [
        ['(nadšenie|nevôľa|dojem|nostalgia|pocit|túžba|cit|podozrenie|pozornosť|rozpaky|strach)'],
    ],
    'vzbudzovať' => [
        ['(nedôvera|ľútosť|dojem|nostalgia|pocit|túžba|záujem|dôvera|ilúzia|nedôvera|podozrenie|rozpaky|sympatia|úsmev)'],
    ],
    'vzdať' => [
        ['(pocta)'],
    ],
    'vzdávať' => [
        ['(pocta)'],
    ],
    'vziať' => [
        ['(ohľad|zreteľ)'],
        ['(právo)'],
    ],
    'vzniesť' => [
        ['(námietka|kritika|sankcia|otázka|dotaz|prosba|protest|pripomienka)'],
        ['(nárok|požiadavka)'],
    ],
    'vznikať' => [
        ['(povinnosť)'],
    ],
    'vzniknúť' => [
        ['(povinnosť)'],
    ],
    'vznášať' => [
        ['(nárok)'],
        ['(kritika|sankcia|otázka|dotaz|prosba|pripomienka)'],
    ],
    'vzplanúť' => [
        ['(hnev|nenávisť|láska)'],
    ],
    'zadať' => [
        ['(príčina|podnet)'],
    ],
    'zanikať' => [
        ['(povinnosť|nárok|právo)'],
    ],
    'zaniknúť' => [
        ['(povinnosť)'],
    ],
    'zastávať' => [
        ['(názor|postoj|stanovisko)'],
    ],
    'zaujať' => [
        ['(postoj|stanovisko|vzťah)'],
    ],
    'zaujímať' => [
        ['(vzťah|postoj|stanovisko)'],
    ],
    'zaznamenať' => [
        ['(prepad|rozkvet|posun|nárast|úspech|vzostup|pokles|strata|výkyv|stagnácia|výhra|návrat)'],
    ],
    'zaznamenávať' => [
        ['(úspech|strata|posun)'],
    ],
    'zbierať,zberať' => [
        ['(odvaha|skúsenosť)'],
    ],
    'zjednať' => [
        ['(náprava|kľud|spravodlivosť)'],
    ],
    'zjednávať' => [
        ['(náprava|kľud)'],
    ],
    'zmocniť' => [
        ['(strach|nenávisť|úzkosť|túžba)'],
    ],
    'zobrať' => [
        ['(odvaha|skúsenosť)'],
    ],
    'zobudiť,prebudiť' => [
        ['(dojem|nostalgia|pocit|povaha|túžba|záujem)'],
    ],
    'získavať' => [
        ['(dôvera|impulz|možnosť|povolenie|právo|prehľad|prísľub|prístup|sľub|súhlas|vplyv|skúsenosť)'],
        ['(dojem)'],
    ],
    'získať' => [
        ['(dôvera|impulz|možnosť|povolenie|právo|prehľad|prísľub|prístup|sľub|súhlas|vplyv|skúsenosť)'],
        ['(dojem)'],
    ],
    'činiť' => [
        ['(rozhodnutie|pokus|krok|opatrenie|pokrok|expertíza|kontrola|obmedzenie|záťah)'],
        ['(dojem)'],
        ['(záver|záver)'],
    ],
);

my %DPHR = (
    'baliť' => [
        ['vercajg'],
    ],
    'behať' => [
        [ 'mráz', 'po', 'chrbát' ],
    ],
    'bežať' => [
        [ 'ako', 'na', 'drôtik' ],
        [ 'ako', 'po', 'drôtik' ],
    ],
    'biť' => [
        [ 'na', 'poplach' ],
    ],
    'brať' => [
        [ 'do', 'úvaha' ],
        [ 'do', 'úvaha' ],
        [ 'na', 'vedomie' ],
        [ 'v',  'úvaha' ],
        [ 'na', 'seba' ],
        ['rozum'],
        ['koniec'],
        [ 'na', 'váha', 'ľahký' ],
        ['ten'],
        ['späť'],
    ],
    'brúsiť si' => [
        ['zub'],
    ],
    'byť' => [
        [ 'k',  'dispozícia' ],
        [ 'na', 'ten' ],
        [ 'na', 'miesto' ],
        ['namieste'],
        [ 'v',      'záujem' ],
        [ 'v',      'záujem' ],
        [ 'to',     's' ],
        [ 'názor', '(iný|rovnaký|podobný|opačný)' ],
        [ 'názor', 'že' ],
        [ 'názor', 'ten', 'že' ],
        [ 'v',      'hra' ],
        [ 'na',     'čas' ],
        ['rad'],
        [ 'na', 'vina' ],
        [ 'za', 'voda' ],
        [ 'na', 'uváženie' ],
        [ 'v',  'úzky' ],
        [ 'na', 'škoda' ],
        [ 'po', 'ruka' ],
        [ 'po', 'ruka' ],
        [ 'v',  'prach' ],
        ['ďaleký'],
        [ 'k',   'dosiahnutie' ],
        [ 'o',   'ten' ],
        [ 'na',  'závada' ],
        [ 'v',   'plán' ],
        [ 'nad', 'všetko' ],
        ['zadobre'],
        [ 'pre',    'mačka' ],
        [ 'v',      'stávka' ],
        [ 'k',      'zaplatenie' ],
        [ 'v',      'obraz' ],
        [ 'na',     'čo' ],
        [ 'mimo',   'obraz' ],
        [ 'do',     'práca' ],
        [ 'mienka', '(iný|rovnaký|podobný)' ],
    ],
    'bývať' => [
        ['ľúto'],
    ],
    'chovať' => [
        [ 'ako', 'v', 'bavlnka' ],
    ],
    'chyba' => [
        ['lávka'],
    ],
    'dať' => [
        ['najavo'],
        ['(spolu|dohromady)'],
        [ 'za', 'pravda' ],
        [ 'k',  'dispozícia' ],
        ['ten'],
        [ 'počuť', '(sa|so)' ],
        ['vedieť'],
        [ 'čakať', 'na', 'seba' ],
        ['práca'],
        [ 'z', 'ruka' ],
        ['zelený'],
        [ 'na', 'vedomie' ],
        ['pokoj'],
        ['rozum'],
        [ 'do', 'súlad' ],
        ['pozor'],
        ['boh'],
    ],
    'docieliť' => [
        ['(môj|svoj)'],
    ],
    'dosahovať' => [
        ['(môj|svoj)'],
    ],
    'dosiahnuť' => [
        ['(môj|svoj)'],
    ],
    'dostať' => [
        ['zabrať'],
        [ 'cez', 'prst' ],
        ['zelený'],
        [ 'na',   'starosť' ],
        [ 'do',   'vienok' ],
        [ 'k',    'dispozícia' ],
        [ 'na',   'frak' ],
        [ 'ruka', 'voľný' ],
        ['spád'],
        ['kanárik'],
        [ 'na', 'zadok' ],
    ],
    'druh' => [
        ['(môj|svoj)'],
    ],
    'držať' => [
        ['rekord'],
        [ 'na',  'uzda' ],
        [ 'v',   'tajnosť' ],
        [ 'nad', 'voda' ],
        ['krok'],
        [ 'v',   'šach' ],
        [ 'na',  'opraty' ],
        [ 'pri', 'život' ],
    ],
    'dávať' => [
        ['najavo'],
        [ 'za', 'pravda' ],
        ['pozor'],
        [ 'na', 'vedomie' ],
        ['vedieť'],
        ['váha'],
        ['(spolu|dokopy)'],
        [ 'k', 'dispozícia' ],
        ['vedieť'],
        ['vina'],
    ],
    'hnúť' => [
        ['žlč'],
        ['brva'],
    ],
    'hodiť' => [
        [ 'za', 'hlava' ],
        ['iskra'],
        [ 'cez', 'paluba' ],
    ],
    'hovoriť' => [
        [ 'za', 'všetko' ],
        [ 'za', '(sa|so)' ],
        [ 'do', 'duša' ],
        [ 'za', 'všetko' ],
        [ 'do', 'duša' ],
    ],
    'hrať' => [
        ['rola'],
        ['prím'],
        ['úloha'],
        [ 'do', 'nota' ],
        [ 'na', 'nerv' ],
        [ 'na', 'strana', 'dva' ],
    ],
    'hádzať' => [
        [ 'poleno', 'pod', 'noha' ],
    ],
    'jadro' => [
        ['pudel'],
    ],
    'koniec' => [
        ['koniec'],
    ],
    'kráčať' => [
        [ 'v', 'šľapaj' ],
        [ 'v', 'šľapaj' ],
    ],
    'lapať' => [
        [ 'po', 'dych' ],
    ],
    'ležať' => [
        [ 'na', 'bedrá' ],
        [ 'na', 'bedrá' ],
    ],
    'liezť' => [
        [ 'do', 'kapusta' ],
        [ 'na', 'nerv' ],
    ],
    'luhať,klamať' => [
        [ 'ako', 'keď', 'tlačiť' ],
    ],
    'lámať' => [
        ['palica'],
        [ 'cez', 'koleno' ],
    ],
    'mať' => [
        [ 'k', 'dispozícia' ],
        ['rád'],
        ['radšej'],
        [ 'v',  'úmysel' ],
        [ 'na', 'myseľ' ],
        [ 'na', 'starosť' ],
        [ 'na', 'starosť' ],
        ['slovo'],
        [ 'na', 'svedomie' ],
        [ 'za', 'následok' ],
        [ 'za', 'ten' ],
        ['váha'],
        [ 'v',  'ruka' ],
        [ 'za', 'cieľ' ],
        [ 'v',  'plán' ],
        ['jasno'],
        [ 'na',  'pamäť' ],
        [ 'pri', 'ruka' ],
        [ 'po',  'ruka' ],
        ['navrch'],
        ['zelený'],
        ['naponáhlo'],
        [ 'zub', 'plný' ],
        [ 'pod', 'dohľad' ],
        [ 'na',  'zreteľ' ],
        [ 'v',   'právomoc' ],
        [ 'v',   'referát' ],
        [ 'na',  'program' ],
        [ 'v',   'prevádzka' ],
        [ 'v',   'obľuba' ],
        ['namále'],
        ['dosť'],
        [ 'v',       'krv' ],
        [ 'hlava',   'ťažký' ],
        [ 'za',      'dôsledok' ],
        [ 'na',      'program' ],
        [ 'v',       'hra' ],
        [ 'robiť',  'čo' ],
        [ 'na',      'vybraný' ],
        [ 'päť',   'všetko', 'pohromade' ],
        [ 'strecha', 'nad', 'hlava' ],
        [ 'z',       'krk' ],
        [ 'dno',     'zlatý' ],
        ['(kľučka|klika)'],
        [ 'ruka', 'šťastný' ],
        [ 'za',   'dôsledok' ],
        ['česť'],
        [ 'v',  'povaha' ],
        [ 'v',  'užívanie' ],
        [ 'po', 'krk' ],
    ],
    'miešať' => [
        [ 'piaty', 'cez', 'deviaty' ],
    ],
    'nasadiť' => [
        ['koruna'],
    ],
    'nasadzovať' => [
        ['koruna'],
    ],
    'naskakovať' => [
        [ 'koža', 'husí' ],
    ],
    'naskočiť' => [
        [ 'koža', 'husí' ],
    ],
    'nastaviť' => [
        ['zrkadlo'],
    ],
    'nechať' => [
        [ 'počuť', '(sa|so)' ],
        [ 'na',      'pokoj' ],
        [ 'ujsť',   '(sa|so)' ],
        [ 'na',      'pochyba' ],
        [ 'ten',     'tak' ],
        [ 'kameň',  'na', 'kameň' ],
    ],
    'nechávať' => [
        [ 'na',      'pochyba' ],
        [ 'počuť', '(sa|so)' ],
    ],
    'niesť' => [
        [ 'koža', 'na', 'trh' ],
    ],
    'obracať' => [
        ['naruby'],
    ],
    'obrať,obrat' => [
        ['ruka'],
    ],
    'obrátiť' => [
        ['list'],
        ['naruby'],
    ],
    'obsadiť' => [
        [ 'do', 'rola' ],
    ],
    'odísť' => [
        [ 'na', 'odpočinok' ],
    ],
    'omlátiť' => [
        [ 'o', 'hlava' ],
    ],
    'padnúť' => [
        [ 'za',       'obeť' ],
        [ 'do',       'oko' ],
        [ 'padnúť', 'kto' ],
        [ 'ako',      'uliaty' ],
        [ 'ako',      'uliaty' ],
        [ 'do',       'nota' ],
    ],
    'pocítiť' => [
        [ 'na', 'koža', 'vlastný' ],
    ],
    'pokrčiť' => [
        ['rameno'],
    ],
    'položiť' => [
        [ 'na', 'lopatka' ],
        ['život'],
    ],
    'pomôcť' => [
        [ 'na', 'noha', 'vlastný' ],
    ],
    'ponechať' => [
        ['napospas'],
    ],
    'popriavať' => [
        ['sluch'],
    ],
    'porovnať' => [
        [ 's', 'zem' ],
    ],
    'postaviť' => [
        [ 'na', 'noha' ],
        ['prekážka'],
    ],
    'praskať' => [
        [ 'v', 'šev' ],
    ],
    'prebiehať' => [
        [ 'ako', 'po', 'maslo' ],
    ],
    'predchádzať' => [
        [ 'pýcha', 'pád' ],
    ],
    'prejsť' => [
        ['ruka'],
        [ 'do', 'zbraň' ],
    ],
    'prerásť' => [
        [ 'cez', 'hlava' ],
    ],
    'presadiť' => [
        ['(môj|svoj)'],
    ],
    'prežiť' => [
        [ 'na', 'koža', 'vlastný' ],
    ],
    'prichádzať' => [
        [ 'v',  'úvaha' ],
        [ 'na', 'rada' ],
        [ 'na', 'pretras' ],
        ['skrátka'],
        ['reč'],
    ],
    'prijať' => [
        [ 'za', '(môj|svoj)' ],
        [ 'na', '(sa|so)' ],
    ],
    'priniesť' => [
        ['jasno'],
        [ 'ovocie', '(môj|svoj)' ],
    ],
    'pripadať' => [
        [ 'v', 'úvaha' ],
    ],
    'pripísať' => [
        [ 'k', 'dobro' ],
    ],
    'priviesť' => [
        [ 'na', 'svet' ],
    ],
    'privádzať' => [
        [ 'na', 'svet' ],
    ],
    'prísť' => [
        [ 'k', 'slovo' ],
        ['skrátka'],
        [ 'na', 'rada' ],
        [ 'na', 'chuť' ],
        ['vhod'],
        [ 'na', 'svet' ],
        [ 'na', 'pomoc' ],
        ['reč'],
        [ 'na', 'myseľ' ],
        [ 'na', 'program', 'deň' ],
        ['nazmar'],
        [ 'k',  'česť' ],
        [ 'na', 'myseľ' ],
        ['vhod'],
        [ 'na', 'pretras' ],
        [ 'k',  '(sa|so)' ],
        [ 'k',  'rozum' ],
    ],
    'pustiť' => [
        [ 'k', 'slovo' ],
        [ 'k', 'voda' ],
    ],
    'robiť' => [
        ['zlodej'],
        ['dobrota'],
        ['svoj'],
        ['neplecha'],
    ],
    'rozviazať' => [
        ['jazyk'],
        ['jazyk'],
        ['jazyk'],
        ['jazyk'],
    ],
    'skloniť' => [
        ['hlava'],
    ],
    'spadnúť' => [
        [ 'do', 'klin' ],
        [ 'z',  'nebo' ],
        [ 'z',  'višňa' ],
    ],
    'spatriť' => [
        [ 'svetlo', 'svet' ],
    ],
    'stratiť' => [
        [ 'z', 'dohľad' ],
        [ 'z', 'oko' ],
        [ 'z', 'dosluch' ],
        [ 'z', 'myseľ' ],
    ],
    'stáť,štát,stať' => [
        [ 'čo', 'stáť' ],
    ],
    'sypať' => [
        [ 'z', 'rukáv' ],
    ],
    'tiahnuť' => [
        ['príklad'],
    ],
    'trafiť' => [
        [ 'do', 'čierny' ],
    ],
    'trvať' => [
        [ 'na', '(môj|svoj)' ],
    ],
    'tvrdiť' => [
        [ 'basa', 'muzika' ],
    ],
    'upútať' => [
        ['pozornosť'],
    ],
    'urobiť' => [
        ['dobre'],
        ['bankrot'],
    ],
    'uviesť' => [
        [ 'na', 'miera', '(správny|pravý)' ],
        [ 'v', 'život' ],
    ],
    'uvádzať' => [
        [ 'v', 'život' ],
        [ 'na', 'miera', 'pravý' ],
    ],
    'učiniť' => [
        ['zadosť'],
        ['(môj|svoj)'],
        ['šťastie'],
    ],
    'ušiť' => [
        [ 'na', 'miera' ],
        [ 'na', 'telo' ],
    ],
    'vedieť' => [
        ['(môj|svoj)'],
    ],
    'vidieť' => [
        [ 'na', 'oko', 'vlastný' ],
        [ 'na', 'oko', 'vlastný' ],
    ],
    'viesť' => [
        ['život'],
        ['reč'],
        [ 'reč', 'hlúpy' ],
    ],
    'visieť' => [
        ['otáznik'],
    ],
    'vybavovať,vyriaďovať' => [
        ['účet'],
    ],
    'vychádzať' => [
        ['najavo'],
    ],
    'vydať' => [
        [ 'na', 'milosť', 'na', 'nemilosť' ],
    ],
    'vyjsť' => [
        ['najavo'],
        ['navrch'],
    ],
    'vykonať' => [
        ['(môj|svoj)'],
    ],
    'vykopať' => [
        [ 'sekera', 'vojnový' ],
    ],
    'vypraviť' => [
        [ 'z', '(sa|so)' ],
    ],
    'vypáliť' => [
        ['rybník'],
    ],
    'vyrážať' => [
        ['dych'],
    ],
    'vystrkovať' => [
        ['rožok'],
    ],
    'vystupovať' => [
        [ 'na', 'povrch' ],
        [ 'do', 'popredie' ],
    ],
    'vytanúť' => [
        [ 'na',   'myseľ' ],
        [ 'pred', 'oko' ],
    ],
    'vyviesť' => [
        [ 'z', 'miera' ],
    ],
    'vyvolávať' => [
        [ 'v', 'život' ],
    ],
    'vziať' => [
        [ 'v',  'úvaha' ],
        [ 'do', 'úvaha' ],
        [ 'do', 'väzba' ],
        [ 'na', 'vedomie' ],
        [ 'za', '(môj|svoj)' ],
        [ 'na', '(sa|so)' ],
        [ 'do', 'ruka', '(môj|svoj)' ],
        [ 'do', 'ruka' ],
        [ 'za', '(môj|svoj)' ],
        [ 'na', '(sa|so)' ],
        ['späť'],
        ['naspäť'],
        [ 'na',   'zreteľ' ],
        [ 'noha', 'na', 'rameno' ],
        [ 'za',   'slovo' ],
        [ 'do',   'zajačí' ],
        [ 'na',   'milosť' ],
        ['roh'],
        [ 'koniec', 'rýchly' ],
        [ 'do',     'väzba' ],
        [ 'do',     'ruka', '(môj|svoj)' ],
    ],
    'vztiahnuť' => [
        ['ruka'],
        ['päsť'],
    ],
    'výčitka' => [
        ['svedomie'],
    ],
    'vŕtať' => [
        ['hlava'],
    ],
    'zachovať' => [
        [ 'pri', 'život' ],
    ],
    'zamiesť' => [
        [ 'prah', 'vlastný' ],
    ],
    'zanechať' => [
        ['napospas'],
    ],
    'zaplatiť' => [
        ['boh'],
    ],
    'zatajiť' => [
        ['dych'],
    ],
    'zatvoriť,zavrieť' => [
        ['ústa'],
    ],
    'zaviesť' => [
        ['reč'],
    ],
    'zavádzať' => [
        ['reč'],
    ],
    'zažiť' => [
        [ 'na', 'koža', 'vlastný' ],
    ],
    'zhoda' => [
        ['okolnosť'],
    ],
    'zlomiť' => [
        ['palica'],
    ],
    'zložiť' => [
        [ 'ruka', 'do', 'klin' ],
    ],
    'zmeniť' => [
        [ 'k', 'dobrý' ],
    ],
    'zohrať' => [
        ['rola'],
        ['úloha'],
    ],
    'zohrávať' => [
        ['rola'],
        ['úloha'],
    ],
    'zostať' => [
        ['sám'],
    ],
    'zostávať' => [
        [ 'v',   'platnosť' ],
        [ 'pri', 'starý' ],
    ],
    'zájsť' => [
        [ 'do', 'krajnosť' ],
    ],
    'zísť' => [
        [ 'z', 'oko' ],
    ],
    'ísť' => [
        [ 'na', 'loď', 'rovnaký' ],
        ['ďaleko'],
        [ 'na',   'odbyt' ],
        [ 'do',   'tuhý' ],
        [ 'ruka', 'v', 'ruka' ],
        ['príklad'],
        [ 'po',      'krk' ],
        [ 'tlstý',  'do', 'tenký' ],
        [ 'z',       'kopec' ],
        [ 's',       'cena' ],
        [ 'kĺzať', '(sa|so)' ],
        ['(spolu|dohromady)'],
        ['vzor'],
        [ 'proti', 'prúd' ],
    ],
    'čakať' => [
        ['dieťa'],
    ],
    'ľahnúť' => [
        ['popol'],
    ],
    'šliapať' => [
        [ 'na', 'päta' ],
    ],
    'ťahať' => [
        [ 'za', 'ucho' ],
    ],
);

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my ($anode) = $tnode->get_lex_anode();

    return if ( $tnode->nodetype ne 'complex' or !$anode );
    
    my $lemma = $tnode->t_lemma;
    $lemma =~ s/_/ /g;

    if ( $CPHR{$lemma} ) {
        return if ( $self->mark_phrasal_parts( 'CPHR', $anode, $CPHR{$lemma} ) );
    }
    if ( $DPHR{$lemma} ) {
        return if ( $self->mark_phrasal_parts( 'DPHR', $anode, $DPHR{$lemma} ) );
    }
    return;
}

# Find and mark parts of a light verb/phraseme. Looks in the given dictionary section with
# light verbs/phraseme meaning variants of the given lemma.
# Returns 1 if a phrase has been found at the current instance
sub mark_phrasal_parts {
    my ( $self, $functor, $anode, $variants ) = @_;

    my $depth           = $anode->get_depth();
    my @adescs          = grep { $_->get_depth() <= $depth + 2 } $anode->get_descendants();
    my %adescs_by_lemma = map { $_->lemma => $_ } @adescs;

    foreach my $parts ( @{$variants} ) {

        # check if all parts of our phrase can be matched among the children
        my $matches = 1;
        my @parts_to_adescs = ();

        foreach my $part ( @{$parts} ) {
            
            my $adesc = first { $_ =~ m/^$part$/ } keys %adescs_by_lemma; 
            
            if ( not $adesc ) {
                $matches = 0;
                last;
            }
            push @parts_to_adescs, $adescs_by_lemma{$adesc};
        }

        next if ( not $matches );

        # we have found a match for the phrase -> mark functors and finish (do not look further)
        foreach my $adesc ( @parts_to_adescs ) {
            my (@tnodes) = $adesc->get_referencing_nodes('a/lex.rf');
            if (@tnodes) {
                map { $_->set_functor($functor) } @tnodes;
            }
        }

        log_info($functor . ' MATCH: ' . $anode->lemma . ' + ' . join(' ', @$parts) . ': ' .  $anode->get_address );
        return 1;
    }
    return 0;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::SK::SetPhrasalFunctors

=head1 DESCRIPTION

Set CPHR and DPHR functors using rules that match lemmas of the verb and its descendants.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
