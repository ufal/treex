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
        [ '(ohľad|zreteľ)' ],
        [ '(podiel)' ],
        [ '(právo|právo)' ],
        [ '(právo)' ],
    ],
    'budiť' => [
        [ '(dojem|nostalgia|pocit|pohoršenie|pozornosť|rozpaky|závisť|zdanie)' ],
    ],
    'byť' => [
        [ 'treba' ],
        [ 'potrebné' ],
        [ 'škoda' ],
        [ '(nutný|možný|vhodný)' ],
        [ '(ťažko|ťažko|zaťažko|treba)' ],
        [ '(hanba)' ],
        [ '(hanba|trápne)' ],
        [ 'jeden' ],
        [ '(ľúto)' ],
    ],
    'bývať' => [
        [ '(ľúto|hanba|hanba|jeden|trápne)' ],
        [ '(treba|potrebné)' ],
        [ '(nutný|možný|zaťažko|treba)' ],
    ],
    'civieť' => [
        [ '(prekvapenie|údiv)' ],
    ],
    'cítiť' => [
        [ '(potreba|nutkanie)' ],
    ],
    'dať' => [
        [ '(zaucho|facka|gól|rana)' ],
        [ '(poverenie|podpora|súhlas|správa|impulz|odpoveď|možnosť|príkaz|nádej|popud|príčina|právo|príležitosť|signál|šanca)' ],
        [ '(prednosť)' ],
        [ '(hlas)' ],
        [ '(dôkaz|informácia|návrh|oznámenie|podnet|sťažnosť|záruka|správa|žiadosť|žaloba)' ],
        [ '(pečať)' ],
        [ '(priestor|možnosť|nádej|popud|právo|príležitosť|šanca)' ],
        [ '(dôkaz|informácia|návrh|oznámenie|podnet|sťažnosť|správa|žiadosť|žaloba)' ],
        [ '(pokuta|sankcia)' ],
        [ '(dôraz)' ],
        [ '(príčina|podnet)' ],
    ],
    'dať_sa' => [
        [ 'do', '(práca|výroba|hospodárenie|výklad|let|pohyb)' ],
        [ 'v', '(let)' ],
    ],
    'dostať' => [
        [ '(šanca|výpoveď|odškodnenie|priestor|odporučenie|informácia|impulz|možnosť|ponuka|návrh|odpoveď|povolenie|pokuta|prednosť|príležitosť|prísľub|prístup|rada|sľub|súhlas|uistenie|rozkaz|úloha|zákaz|správa)' ],
        [ '(chuť|nápad)' ],
    ],
    'dostať_sa' => [
        [ 'do', '(styk|konflikt|spor)' ],
    ],
    'dostávať' => [
        [ '(priestor|odporučenie|impulz|možnosť|ponuka|návrh|odpoveď|povolenie|pokuta|prednosť|príležitosť|prísľub|prístup|sľub|súhlas|uistenie|rozkaz|úloha|zákaz|správa)' ],
    ],
    'dávať' => [
        [ '(priestor|poverenie|podpora|impulz|možnosť|príkaz|nádej|popud|príčina|právo|príležitosť|signál|šanca)' ],
        [ '(prednosť)' ],
        [ '(dôkaz|informácia|návrh|oznámenie|podnet|sťažnosť|správa|žiadosť|žaloba)' ],
        [ '(dôraz)' ],
        [ '(pokuta|sankcia|výpoveď)' ],
        [ '(zaucho|facka)' ],
        [ '(príčina|podnet)' ],
    ],
    'dávať_sa' => [
        [ 'do', '(pohyb|práca|pochod|výroba|hospodárenie|výklad)' ],
    ],
    'horieť' => [
        [ '(nenávisť|túžba)' ],
    ],
    'javiť' => [
        [ '(záujem)' ],
    ],
    'klásť' => [
        [ '(otázka|otázka)' ],
        [ '(dôraz)' ],
        [ '(nárok|požiadavka)' ],
        [ '(odpor|podmienka|prekážka|cieľ|medza)' ],
        [ '(dopyt|otázka)' ],
        [ '(bariéra|prekážka)' ],
        [ 'otázka' ],
    ],
    'mať' => [
        [ '(dlh|oprávnenie|túžba|úloha|záväzok|sila|pochybnosť|predstava|cieľ|čas|česť|chuť|mechanizmus|možnosť|nádej|pocit|potreba|povinnosť|odvaha|právo|právomoc|schopnosť|sklon|snaha|šanca|tušenie|zámer)' ],
        [ 'potreba' ],
        [ '(záujem)' ],
        [ '(ťažkosť|problém)' ],
        [ '(dosah|nárok|účinok|vplyv)' ],
        [ '(obava|potešenie|strach|radosť|dojem)' ],
        [ '(predpoklad|sklon|tendencia|plán|šanca)' ],
        [ '(priestor|dôvod|motivácia|príležitosť)' ],
        [ '(zmysel|význam|cena)' ],
        [ '(meškanie|skúsenosť)' ],
        [ '(podiel|zásluha)' ],
        [ '(námietka|výhrada|nič|niečo)' ],
        [ '(nedôvera|prednosť|rešpekt|náskok|dôvera)' ],
        [ '(názor|mienka)' ],
        [ '(následok|dôsledok)' ],
        [ '(vzťah)' ],
        [ '(prevaha)' ],
        [ '(povolenie|zvolenie|súhlas)' ],
        [ '(rešpekt|dôvera)' ],
        [ '(pripomienka|poznámka|návrh)' ],
        [ '(záruka)' ],
        [ '(styk)' ],
        [ '(dozor|dohľad)' ],
    ],
    'mávať' => [
        [ '(predstava|spomienka|pocit)' ],
        [ '(podiel|zásluha)' ],
        [ '(pripomienka|poznámka)' ],
        [ '(dosah|vplyv)' ],
        [ '(prednosť|rešpekt|náskok)' ],
        [ '(čas|česť|chuť|možnosť|nádej|potreba|povinnosť|povolenie|právo|právomoc|schopnosť|snaha|šanca)' ],
        [ '(zmysel|význam|cena)' ],
        [ '(predpoklad|sklon|tendencia)' ],
        [ '(obava|potešenie|strach)' ],
        [ '(ťažkosť|problém|porucha)' ],
        [ '(dôvod|motivácia|príležitosť)' ],
        [ '(záujem)' ],
        [ '(dôvera|vzťah)' ],
    ],
    'naberať' => [
        [ '(odvaha|skúsenosť)' ],
    ],
    'nabrať' => [
        [ '(odvaha|skúsenosť)' ],
    ],
    'nachádzať' => [
        [ '(odvaha|potešenie|východisko|riešenie|uplatnenie)' ],
    ],
    'nadobudnúť' => [
        [ '(dojem|presvedčenie)' ],
    ],
    'nadviazať' => [
        [ '(dialóg|kontakt|zmluva|spojenie|spolupráca|styk|vzťah)' ],
    ],
    'nadväzovať' => [
        [ '(dialóg|kontakt|zmluva|spojenie|spolupráca|styk|vzťah)' ],
    ],
    'navodiť' => [
        [ '(dojem|nostalgia|pocit|pohoršenie|túžba)' ],
    ],
    'navodzovať' => [
        [ '(dojem|nostalgia|pocit|pohoršenie|túžba|atmosféra|myšlienka|predstava)' ],
    ],
    'nazbierať' => [
        [ '(odvaha|skúsenosť|poznatok)' ],
        [ '(odvaha|skúsenosť)' ],
    ],
    'niesť' => [
        [ '(zodpovednosť|strata|zodpovednosť|vina|riziko|dôsledok|následok|miera|spoluvina)' ],
    ],
    'nájsť' => [
        [ '(možnosť|odvaha|potešenie|riešenie|východisko|uplatnenie)' ],
        [ '(možnosť|odvaha|odpoveď|potešenie|riešenie|východisko|uplatnenie)' ],
    ],
    'obracať' => [
        [ '(pozornosť)' ],
    ],
    'obrátiť' => [
        [ '(pozornosť)' ],
    ],
    'otvoriť' => [
        [ '(možnosť|prístup|cesta|priestor)' ],
    ],
    'otvárať' => [
        [ '(možnosť|prístup|priestor|cesta)' ],
        [ '(možnosť|priestor|prístup|čo)' ],
    ],
    'ovládnuť' => [
        [ '(hnev)' ],
    ],
    'padnúť' => [
        [ '(slovo|zmienka|rozhodnutie|otázka|poznámka|návrh)' ],
    ],
    'planúť' => [
        [ '(nenávisť|túžba)' ],
    ],
    'pociťovať' => [
        [ '(potreba|nutkanie)' ],
    ],
    'pocítiť' => [
        [ '(potreba|nutkanie)' ],
    ],
    'podať' => [
        [ '(odvolanie|vysvetlenie|protest|dôkaz|informácia|návod|návrh|obžaloba|podnet|pokyn|sťažnosť|výpoveď|správa|žiadosť|žaloba)' ],
        [ '(výkon)' ],
        [ '(demisia|odvolanie)' ],
        [ '(dôkaz|informácia|návrh|odvolanie|podnet|sťažnosť|výpoveď|správa|žiadosť|žaloba)' ],
        [ '(obžaloba|dôkaz|informácia|návrh|podnet|protest|sťažnosť|výpoveď|správa|žiadosť|žaloba)' ],
        [ '(informácia|podnet|správa)' ],
    ],
    'podnikať' => [
        [ '(krok|opatrenie)' ],
    ],
    'podniknúť' => [
        [ '(krok|opatrenie)' ],
        [ '(obsadenie|invázia|útok|zájazd)' ],
    ],
    'podávať' => [
        [ '(odvolanie|protest|dôkaz|informácia|návrh|návod|podnet|sťažnosť|svedectvo|správa|žiadosť|žaloba)' ],
        [ '(výkon)' ],
        [ '(protest|dôkaz|informácia|návrh|podnet|sťažnosť|správa|žiadosť|žaloba)' ],
        [ '(protest|dôkaz|informácia|návrh|sťažnosť|správa|žiadosť|žaloba)' ],
        [ '(informácia|podnet|správa)' ],
    ],
    'položiť' => [
        [ '(otázka|otázka)' ],
        [ '(dôraz|dôraz)' ],
    ],
    'ponúkať_sa' => [
        [ '(spolupráca|možnosť|riešenie)' ],
        [ '(možnosť|výhľad)' ],
    ],
    'ponúknuť_sa' => [
        [ '(pohľad|možnosť|výhľad)' ],
    ],
    'poskytnúť' => [
        [ '(rozhovor|výchova|ubytovanie|dotácia|kompenzácia|pôžička|garancia|informácia|liečenie|možnosť|ochrana|pomoc|podpora|záruka|rada|služba)' ],
    ],
    'poskytovať' => [
        [ '(dotácia|informácia|príspevok|liečenie|starostlivosť|činnosť|možnosť|ochrana|podpora|pomoc|záruka|rada|služba|pôžička|zľava)' ],
        [ '(možnosť|pomoc|záruka|rada|služba)' ],
    ],
    'prebudiť' => [
        [ '(dojem|nostalgia|pocit|pohoršenie|povaha|túžba|záujem)' ],
    ],
    'prebúdzať' => [
        [ '(dojem|nostalgia|pocit|pohoršenie|túžba|záujem)' ],
    ],
    'prechovávať' => [
        [ '(dôvera|podozrenie|nenávisť|nádej|priateľstvo|cit)' ],
    ],
    'prejaviť' => [
        [ '(nezáujem|nesúhlas|záujem|ľútosť|nadšenie|prianie|názor)' ],
        [ '(nedôvera|dôvera|sústrasť|úcta|uznanie)' ],
    ],
    'prejavovať' => [
        [ '(nesúhlas|záujem|ľútosť|nadšenie|prianie)' ],
        [ '(dôvera|sústrasť|úcta|uznanie)' ],
    ],
    'prichádzať' => [
        [ 'do', '(styk|kontakt)' ],
        [ 's', '(nápad|návrh|opatrenie)' ],
        [ 'o', '(možnosť|právo|ilúzia)' ],
        [ 'na', '(nápad|riešenie)' ],
    ],
    'prijať' => [
        [ '(rozhodnutie|opatrenie|uznesenie|záver)' ],
    ],
    'prijímať' => [
        [ '(rozhodnutie|opatrenie|riešenie)' ],
    ],
    'prislúchať' => [
        [ '(oprávnenie|právo)' ],
    ],
    'pristupovať' => [
        [ 'k', '(hlasovanie|realizácia|plán|udelenie|zmena|obnova|modernizácia)' ],
    ],
    'pristúpiť' => [
        [ 'k', '(použitie|stimulácia|vypovedaniu|likvidácia|jednanie|riešenie|premena|hlasovanie|kontrola|krok|realizácia|plán|udelenie|zmena|uťahovanie|uhradeniu)' ],
    ],
    'prísť' => [
        [ 's', '(tvrdenie|nápad|návrh|myšlienka|požiadavka|riešenie)' ],
        [ 'do', '(styk|kontakt)' ],
        [ 'o', '(výhoda|možnosť|právo|ilúzia)' ],
        [ 'na', '(nápad|riešenie)' ],
    ],
    'pustiť_sa' => [
        [ 'do', '(polemika|čítanie|boj|podnikanie|písanie|príprava|špekulácia|akcia|práca|výroba|hospodárenie|výklad|vývoj)' ],
    ],
    'púšťať_sa' => [
        [ 'do', '(polemika|kontakt|práca|výroba|hospodárenie|výklad|počet|opis)' ],
    ],
    'robiť' => [
        [ '(rozhodnutie|pokus|krok|opatrenie|pokrok|expertíza|kontrola|obmedzenie|záťah)' ],
        [ '(dojem)' ],
        [ '(záver|záver)' ],
        [ '(rozhovor|práca|prognóza|sľub|test|chyba|inštruktáž|obhliadka|propagácia|prieskum|reorganizácia|reštrukturalizácia|údržba|ústupok|vklad|hodnotenie|pokus|krok|opatrenie|pokrok|expertíza|kontrola|obmedzenie|vyšetrenie|záťah)' ],
        [ '(záver)' ],
        [ '(dozor|uzdravovanie|skutok|čin|pokus|príprava|práca|pozorovanie)' ],
        [ '(kópia|zápis|záznam)' ],
        [ '(odber|aktualizácia|farbenie|dozor|inštruktáž|obhliadka|prieskum|reorganizácia|reštrukturalizácia|úkon|údržba|úprava|test|vklad|hodnotenie|zmena)' ],
        [ '(debata|dialóg|rozhovor|pohovor)' ],
        [ '(operácia)' ],
    ],
    'robiť_si' => [
        [ '(predstava|nárok|nádej)' ],
    ],
    'spriadať' => [
        [ '(plán|úvaha)' ],
    ],
    'stratiť' => [
        [ '(nádej|odvaha|radosť|zmysel)' ],
        [ '(chuť|možnosť|príležitosť)' ],
    ],
    'strácať' => [
        [ '(nádej|odvaha|radosť|zmysel)' ],
        [ '(chuť|príležitosť)' ],
    ],
    'udeliť' => [
        [ '(cena|pochvala|pokuta|rada|súhlas|uznanie)' ],
    ],
    'udeľovať' => [
        [ '(autorizácia|cena|trest|pochvala|pokuta|rada|súhlas|uznanie|titul|splnomocnenie)' ],
    ],
    'ukladať' => [
        [ '(trest|povinnosť|pokuta|sankcia|penále|úloha)' ],
    ],
    'uložiť' => [
        [ '(trest|napomenutie|povinnosť|pokuta|sankcia)' ],
    ],
    'uprieť' => [
        [ '(pozornosť|zrak)' ],
    ],
    'urobiť' => [
        [ '(zápis|záznam)' ],
        [ '(rozbor|vyšetrenie|aktualizácia|odškodnenie|inštruktáž|obhliadka|prieskum|reorganizácia|reštrukturalizácia|údržba|test|vklad|hodnotenie|zmena|znárodnenie)' ],
        [ '(operácia)' ],
        [ '(debata|dialóg|rozhovor|hovor)' ],
        [ '(rozhodnutie|prehlásenie|previerka|expertíza|kontrola|obmedzenie|oznámenie|záťah|pokus|krok|opatrenie|pokrok)' ],
        [ '(ústupok|ponuka)' ],
        [ '(záver|zhrnutie)' ],
        [ '(koniec|koniec)' ],
        [ '(dojem)' ],
        [ '(rozhodnutie|škrt|výber|ústupok|pokus|krok|chyba|opatrenie|pokrok|expertíza|kontrola|obmedzenie|výskum|záťah)' ],
        [ '(záver)' ],
    ],
    'urobiť_si' => [
        [ '(predstava|úsudok|čas|žart)' ],
    ],
    'uskutočniť' => [
        [ '(rozbor|vyšetrenie|aktualizácia|odškodnenie|inštruktáž|obhliadka|prieskum|reorganizácia|reštrukturalizácia|údržba|test|vklad|hodnotenie|zmena|znárodnenie)' ],
        [ '(operácia)' ],
        [ '(debata|dialóg|rozhovor|hovor)' ],
    ],
    'uskutočňovať' => [
        [ '(odber|aktualizácia|farbenie|dozor|inštruktáž|obhliadka|prieskum|reorganizácia|reštrukturalizácia|úkon|údržba|úprava|test|vklad|hodnotenie|zmena)' ],
        [ '(debata|dialóg|rozhovor|pohovor)' ],
        [ '(operácia)' ],
    ],
    'uvaliť' => [
        [ '(blokáda|clo|daň|embargo|exekúcia|hypotéka|karanténa|sankcia|väzba)' ],
    ],
    'uzatvárať' => [
        [ '(dohoda|kompromis|kontrakt|zmluva|prímerie|stávka)' ],
    ],
    'uzavrieť' => [
        [ '(partnerstvo|vzťah|dohoda|obchod|kontrakt|zmluva|zmier|sobáš|mier|prímerie|stávka|účet)' ],
    ],
    'venovať' => [
        [ '(pozornosť|čas|záujem|priestor|starostlivosť|opatera|priazeň|lojalita)' ],
    ],
    'viesť' => [
        [ '(kampaň|riadenie|útok|operácia|komunikácia|pohovor|boj|debata|dialóg|diskusia|jednanie|polemika|propaganda|rozhovor|hovor|spor|výprava|vojna|vyjednávanie)' ],
        [ '(stíhanie|žaloba)' ],
    ],
    'vojsť' => [
        [ 'do', '(platnosť|povedomie|styk)' ],
    ],
    'vrhať' => [
        [ '(tieň|podozrenie|svetlo)' ],
    ],
    'vrhnúť' => [
        [ '(tieň|podozrenie|svetlo)' ],
    ],
    'vstupovať' => [
        [ 'do', '(platnosť)' ],
    ],
    'vstúpiť' => [
        [ 'do', '(platnosť|povedomie...)' ],
    ],
    'vydať' => [
        [ '(zákaz|pokyn|rozkaz|súhlas|príkaz)' ],
    ],
    'vydávať' => [
        [ '(pokyn|rozkaz|súhlas|príkaz|povolenie)' ],
    ],
    'vyhlasovať' => [
        [ '(boj|vojna|preferencia)' ],
    ],
    'vyhlásiť' => [
        [ '(boj|vojna)' ],
    ],
    'vyjadriť' => [
        [ '(prianie|presvedčenie|údiv|obdiv|poľutovanie|sklamanie|obava|súhlas|odhodlanie|ochota|uspokojenie|nádej|potešenie|rozhorčenie|prekvapenie|spokojnosť|hodnotenie|rozčarovanie|pripravenosť|znepokojenie|podozrenie|úzkosť|stanovisko|pochybnosť|protest|záujem|vôľa|pochopenie|postoj|nechápavosť|názor|poďakovanie)' ],
        [ '(vďaka|dôvera|sústrasť|úcta|uznanie|podpora|sympatia|preferencia)' ],
    ],
    'vyjadrovať' => [
        [ '(presvedčenie|údiv|obdiv|sklamanie|obava|súhlas|odhodlanie|ochota|uspokojenie|nádej|potešenie|rozhorčenie|prekvapenie|spokojnosť|hodnotenie|rozčarovanie|pripravenosť|znepokojenie|podozrenie|úzkosť|stanovisko|pochybnosť|protest|záujem|vôľa|pochopenie|postoj|nechápavosť|názor|poďakovanie)' ],
        [ '(dôvera|sústrasť|úcta|uznanie|podpora|sympatia|preferencia)' ],
    ],
    'vykonať' => [
        [ '(poradenstvo|správa|návšteva|sľub|test|inštruktáž|obhliadka|prieskum|reorganizácia|reštrukturalizácia|údržba|vklad|hodnotenie)' ],
    ],
    'vykonávať' => [
        [ '(práca|dozor|služba|činnosť|sľub|inventarizácia|test|inštruktáž|obhliadka|prieskum|reorganizácia|reštrukturalizácia|údržba|vklad|hodnotenie)' ],
    ],
    'vyniesť' => [
        [ '(súd|rozsudok|trest)' ],
    ],
    'vypovedať' => [
        [ '(vojna)' ],
    ],
    'vysloviť' => [
        [ '(obvinenie|nesúhlas|námietka|informácia|názor|znepokojenie|súhlas|spokojnosť|prianie|uspokojenie|ľútosť|hypotéza|predpoklad|verdikt|idea|myšlienka|podozrenie|presvedčenie|domnienka|požiadavka|obava|potreba|predpoveď)' ],
        [ '(dôvera|nedôvera|podpora|kompliment)' ],
    ],
    'vyslovovať' => [
        [ '(nesúhlas|názor|znepokojenie|súhlas|spokojnosť|prianie|uspokojenie|ľútosť|predpoklad|verdikt|idea|myšlienka|podozrenie|presvedčenie|domnienka|požiadavka|obava|potreba|predpoveď)' ],
        [ '(dôvera|nedôvera|podpora|kompliment)' ],
    ],
    'vytvoriť' => [
        [ '(zápis|záznam)' ],
    ],
    'vyvinúť' => [
        [ '(činnosť|nátlak|tlak|snaha|úsilie)' ],
    ],
    'vyvolať' => [
        [ '(neistota|protest|presvedčenie|rozpaky|dohad|dojem|dôvera|nálada|nadšenie|požiadavka|rozčarovanie|napätie|nedôvera|nevôľa|odpor|panika|pochybnosť|prejav|reakcia|snaha|záujem|zdesenie|zmätok|zvedavosť)' ],
    ],
    'vyvolávať' => [
        [ '(protest|presvedčenie|rozpaky|údiv|spomienka|spomienka|dohad|dojem|dôvera|nadšenie|napätie|nedôvera|nevôľa|odpor|panika|pochybnosť|prejav|reakcia|snaha|záujem|zdesenie|zmätok|zvedavosť)' ],
    ],
    'vyvíjať' => [
        [ '(nátlak|tlak|snaha|činnosť)' ],
    ],
    'vzbudiť' => [
        [ '(dojem|nostalgia|pocit|pohoršenie|povaha|túžba|záujem)' ],
        [ '(nechuť|nadšenie|nevôľa|dojem|nostalgia|pocit|pohoršenie|túžba|cit|pobúrenie|podozrenie|pozornosť|rozpaky|strach|rozhorčenie)' ],
    ],
    'vzbudzovať' => [
        [ '(dojem|nostalgia|pocit|pohoršenie|túžba|záujem)' ],
        [ '(nedôvera|ľútosť|dojem|nostalgia|pocit|pohoršenie|túžba|záujem|dôvera|ilúzia|mrazenie|nedôvera|podozrenie|pochybnosť|rozpaky|sympatia|úsmev)' ],
    ],
    'vzdať' => [
        [ '(pocta)' ],
    ],
    'vzdávať' => [
        [ '(pocta)' ],
    ],
    'vziať' => [
        [ '(ohľad|zreteľ)' ],
        [ '(právo)' ],
    ],
    'vzniesť' => [
        [ '(námietka|kritika|sankcia|obvinenie|otázka|prosba|protest|pripomienka)' ],
        [ '(nárok|požiadavka)' ],
    ],
    'vznikať' => [
        [ '(povinnosť)' ],
    ],
    'vzniknúť' => [
        [ '(povinnosť)' ],
    ],
    'vznášať' => [
        [ '(nárok)' ],
        [ '(kritika|sankcia|otázka|prosba|pripomienka)' ],
    ],
    'vzplanúť' => [
        [ '(hnev|zlosť|nenávisť|láska)' ],
    ],
    'zabezpečiť' => [
        [ '(náprava|pokoj|spravodlivosť)' ],
    ],
    'zabezpečovať' => [
        [ '(náprava|pokoj)' ],
    ],
    'zanikať' => [
        [ '(povinnosť|nárok|právo)' ],
    ],
    'zaniknúť' => [
        [ '(povinnosť)' ],
    ],
    'zastávať' => [
        [ '(názor|postoj|stanovisko)' ],
    ],
    'zaujať' => [
        [ '(postoj|stanovisko|vzťah)' ],
    ],
    'zaujímať' => [
        [ '(vzťah|postoj|stanovisko)' ],
    ],
    'zaznamenať' => [
        [ '(prepad|rozkvet|posun|nárast|úspech|vzostup|pokles|strata|výkyv|stagnácia|výhra|návrat)' ],
    ],
    'zaznamenávať' => [
        [ '(úspech|strata|posun)' ],
    ],
    'zbierať' => [
        [ '(odvaha|skúsenosť)' ],
    ],
    'zmocniť_sa' => [
        [ '(podozrenie)' ],
        [ '(strach|nenávisť)' ],
    ],
    'zmocovať_sa' => [
        [ '(strach|nenávisť|úzkosť|túžba)' ],
    ],
    'získavať' => [
        [ '(vedomosť|odvaha|skúsenosť)' ],
        [ '(dôvera|impulz|možnosť|povolenie|právo|prehľad|prísľub|prístup|sľub|súhlas|vplyv|skúsenosť)' ],
        [ '(dojem|presvedčenie)' ],
    ],
    'získať' => [
        [ '(dôvera|impulz|možnosť|povolenie|právo|prehľad|prísľub|prístup|sľub|súhlas|vplyv|skúsenosť)' ],
        [ '(dojem|presvedčenie)' ],
    ],
);

my %DPHR = (
    'baliť' => [
        [ 'vercajg' ],
    ],
    'behať' => [
        [ 'mráz', 'po', 'chrbát' ],
    ],
    'bežať' => [
        [ 'ako', 'po', 'maslo' ],
        [ 'ako', 'po', 'drôtik' ],
    ],
    'biť' => [
        [ 'na', 'poplach' ],
    ],
    'brať' => [
        [ 'do', 'úvaha' ],
        [ 'na', 'vedomie' ],
        [ 'na', 'seba' ],
        [ 'rozum' ],
        [ 'koniec' ],
        [ 'na', 'váha', 'ľahký' ],
        [ 'ten' ],
        [ 'späť' ],
        [ 'vďačne' ],
    ],
    'brať_si' => [
        [ 'na', 'muška' ],
    ],
    'brúsiť_si' => [
        [ 'zub' ],
    ],
    'byť' => [
        [ 'k', 'dispozícia' ],
        [ 'na', 'ten' ],
        [ 'na', 'miesto' ],
        [ 'namieste' ],
        [ 'v', 'záujem' ],
        [ 'to', 's' ],
        [ 'názor', '(iný|rovnaký|podobný|opačný)' ],
        [ 'názor', 'že' ],
        [ 'názor', 'ten', 'že' ],
        [ 'v', 'hra' ],
        [ 'na', 'čas' ],
        [ 'rad' ],
        [ 'na', 'vina' ],
        [ 'za', 'voda' ],
        [ 'na', 'uváženie' ],
        [ 'v', 'úzky' ],
        [ 'na', 'škoda' ],
        [ 'po', 'ruka' ],
        [ 'v', 'prach' ],
        [ 'ďaleký' ],
        [ 'k', 'dosiahnutie' ],
        [ 'o', 'ten' ],
        [ 'na', 'závada' ],
        [ 'v', 'plán' ],
        [ 'nad', 'všetko' ],
        [ 'zadobre' ],
        [ 'pre', 'mačka' ],
        [ 'v', 'stávka' ],
        [ 'k', 'zaplatenie' ],
        [ 'v', 'obraz' ],
        [ 'na', 'čo' ],
        [ 'mimo', 'obraz' ],
        [ 'do', 'práca' ],
        [ 'mienka', '(iný|rovnaký|podobný)' ],
    ],
    'bývať' => [
        [ 'ľúto' ],
    ],
    'chovať' => [
        [ 'ako', 'v', 'bavlnka' ],
    ],
    'chyba' => [
        [ 'lávka' ],
    ],
    'dať' => [
        [ 'najavo' ],
        [ '(spolu|dohromady)' ],
        [ 'za', 'pravda' ],
        [ 'k', 'dispozícia' ],
        [ 'na', 'vedomie' ],
        [ 'ten' ],
        [ 'počuť', 'sa' ],
        [ 'vedieť' ],
        [ 'čakať', 'na', 'seba' ],
        [ 'práca' ],
        [ 'z', 'ruka' ],
        [ 'zelený' ],
        [ 'pokoj' ],
        [ 'rozum' ],
        [ 'do', 'súlad' ],
        [ 'pozor' ],
        [ 'boh' ],
    ],
    'docieliť' => [
        [ '(môj|svoj)' ],
    ],
    'dohovoriť' => [
        [ 'poriadok' ],
    ],
    'dosahovať' => [
        [ '(môj|svoj)' ],
    ],
    'dosiahnuť' => [
        [ '(môj|svoj)' ],
    ],
    'dostať' => [
        [ 'zabrať' ],
        [ 'po', 'prst' ],
        [ 'zelený' ],
        [ 'na', 'starosť' ],
        [ 'do', 'vienok' ],
        [ 'k', 'dispozícia' ],
        [ 'na', 'frak' ],
        [ 'ruka', 'voľný' ],
        [ 'spád' ],
        [ 'kanárik' ],
        [ 'na', 'zadok' ],
    ],
    'druh' => [
        [ 'svoj' ],
    ],
    'držať' => [
        [ 'rekord' ],
        [ 'na', 'uzda' ],
        [ 'v', 'tajnosť' ],
        [ 'nad', 'voda' ],
        [ 'krok' ],
        [ 'v', 'šach' ],
        [ 'na', 'opraty' ],
        [ 'pri', 'život' ],
    ],
    'dávať' => [
        [ 'najavo' ],
        [ 'za', 'pravda' ],
        [ 'pozor' ],
        [ 'na', 'vedomie' ],
        [ 'vedieť' ],
        [ 'váha' ],
        [ '(spolu|dokopy)' ],
        [ 'k', 'dispozícia' ],
        [ 'vina' ],
    ],
    'hodiť' => [
        [ 'za', 'hlava' ],
        [ 'iskra' ],
        [ 'cez', 'paluba' ],
    ],
    'hovoriť' => [
        [ 'za', 'všetko' ],
        [ 'za', 'seba' ],
        [ 'do', 'duša' ],
    ],
    'hrať' => [
        [ 'rola' ],
        [ 'prím' ],
        [ 'úloha' ],
        [ 'do', 'nota' ],
        [ 'na', 'nerv' ],
        [ 'na', 'strana', 'dva' ],
    ],
    'hádzať' => [
        [ 'poleno', 'pod', 'noha' ],
    ],
    'jadro' => [
        [ 'pudel' ],
    ],
    'klamať' => [
        [ 'ako', 'keď', 'tlačiť' ],
    ],
    'koniec' => [
        [ 'koniec' ],
    ],
    'kráčať' => [
        [ 'v', 'šľapaj' ],
    ],
    'lapať' => [
        [ 'po', 'dych' ],
    ],
    'ležať' => [
        [ 'na', 'bedrá' ],
    ],
    'liezť' => [
        [ 'do', 'kapusta' ],
        [ 'na', 'nerv' ],
    ],
    'luhať' => [
        [ 'ako', 'keď', 'tlačiť' ],
    ],
    'lámať' => [
        [ 'palica' ],
        [ 'cez', 'koleno' ],
    ],
    'lámať_si' => [
        [ 'hlava' ],
    ],
    'mať' => [
        [ 'k', 'dispozícia' ],
        [ 'rád' ],
        [ 'radšej' ],
        [ 'v', 'úmysel' ],
        [ 'na', 'myseľ' ],
        [ 'na', 'starosť' ],
        [ 'slovo' ],
        [ 'na', 'svedomie' ],
        [ 'za', 'následok' ],
        [ 'za', 'ten' ],
        [ 'váha' ],
        [ 'v', 'ruka' ],
        [ 'za', 'cieľ' ],
        [ 'v', 'plán' ],
        [ 'jasno' ],
        [ 'hlboko', 'do', 'kapsa' ],
        [ 'na', 'pamäť' ],
        [ 'po', 'ruka' ],
        [ 'za', 'zlý' ],
        [ 'navrch' ],
        [ 'zelený' ],
        [ 'naponáhlo' ],
        [ 'zub', 'plný' ],
        [ 'pod', 'dohľad' ],
        [ 'na', 'zreteľ' ],
        [ 'v', 'právomoc' ],
        [ 'v', 'referát' ],
        [ 'na', 'program' ],
        [ 'v', 'prevádzka' ],
        [ 'v', 'obľuba' ],
        [ 'namále' ],
        [ 'dosť' ],
        [ 'v', 'krv' ],
        [ 'hlava', 'ťažký' ],
        [ 'za', 'dôsledok' ],
        [ 'v', 'hra' ],
        [ 'robiť', 'čo' ],
        [ 'na', 'vybraný' ],
        [ 'päť', 'všetko', 'pohromade' ],
        [ 'strecha', 'nad', 'hlava' ],
        [ 'z', 'krk' ],
        [ 'dno', 'zlatý' ],
        [ 'šťastie' ],
        [ 'ruka', 'šťastný' ],
        [ 'česť' ],
        [ 'v', 'povaha' ],
        [ 'v', 'užívanie' ],
        [ 'po', 'krk' ],
    ],
    'miešať' => [
        [ 'piaty', 'cez', 'deviaty' ],
    ],
    'nabaľovať' => [
        [ 'na', 'seba' ],
    ],
    'nasadiť' => [
        [ 'koruna' ],
    ],
    'nasadzovať' => [
        [ 'koruna' ],
    ],
    'naskakovať' => [
        [ 'koža', 'husí' ],
    ],
    'naskočiť' => [
        [ 'koža', 'husí' ],
    ],
    'nastaviť' => [
        [ 'zrkadlo' ],
    ],
    'nechať' => [
        [ 'počuť', 'seba' ],
        [ 'na', 'pokoj' ],
        [ 'ujsť', 'si' ],
        [ 'v', 'štich' ],
        [ 'na', 'pochyba' ],
        [ 'to', 'tak' ],
        [ 'kameň', 'na', 'kameň' ],
    ],
    'nechávať' => [
        [ 'na', 'štich' ],
        [ 'na', 'pochyba' ],
        [ 'počuť', 'seba' ],
    ],
    'nevidieť' => [
        [ 'čo' ],
    ],
    'niesť' => [
        [ 'koža', 'na', 'trh' ],
    ],
    'niesť_sa' => [
        [ 'v', 'znamenie' ],
    ],
    'obracať' => [
        [ 'naruby' ],
    ],
    'obracať_sa' => [
        [ 'k', 'dobrý' ],
    ],
    'obrat' => [
        [ 'ruka' ],
    ],
    'obrať' => [
        [ 'ruka' ],
    ],
    'obrátiť' => [
        [ 'list' ],
        [ 'naruby' ],
    ],
    'obsadiť' => [
        [ 'do', 'rola' ],
    ],
    'ocitnúť_sa' => [
        [ 'na', 'ľad', 'tenký' ],
    ],
    'odísť' => [
        [ 'na', 'odpočinok' ],
    ],
    'omlátiť' => [
        [ 'o', 'hlava' ],
    ],
    'padnúť' => [
        [ 'za', 'obeť' ],
        [ 'do', 'oko' ],
        [ 'padnúť', 'kto' ],
        [ 'ako', 'uliaty' ],
        [ 'do', 'nota' ],
    ],
    'pocítiť' => [
        [ 'na', 'koža', 'vlastný' ],
    ],
    'pohnúť' => [
        [ 'žlč' ],
        [ 'brva' ],
    ],
    'pokrčiť' => [
        [ 'rameno' ],
    ],
    'položiť' => [
        [ 'na', 'lopatka' ],
        [ 'život' ],
    ],
    'pomôcť' => [
        [ 'na', 'noha', 'vlastný' ],
    ],
    'ponechať' => [
        [ 'napospas' ],
    ],
    'popriavať' => [
        [ 'sluch' ],
    ],
    'postaviť' => [
        [ 'na', 'noha' ],
        [ 'prekážka' ],
    ],
    'praskať' => [
        [ 'v', 'švík' ],
    ],
    'prebiehať' => [
        [ 'ako', 'po', 'maslo' ],
    ],
    'predchádzať' => [
        [ 'pýcha', 'pád' ],
    ],
    'prejsť' => [
        [ 'ruka' ],
        [ 'do', 'zbraň' ],
    ],
    'prerásť' => [
        [ 'cez', 'hlava' ],
    ],
    'presadiť' => [
        [ 'svoj' ],
    ],
    'prežiť' => [
        [ 'na', 'koža', 'vlastný' ],
    ],
    'prichádzať' => [
        [ 'do', 'úvaha' ],
        [ 'na', 'rad' ],
        [ 'na', 'pretras' ],
        [ 'skrátka' ],
        [ 'reč' ],
    ],
    'prijať' => [
        [ 'za', 'svoj' ],
        [ 'na', 'seba' ],
    ],
    'priniesť' => [
        [ 'jasno' ],
        [ 'ovocie', 'svoj' ],
    ],
    'pripadať' => [
        [ 'do', 'úvaha' ],
    ],
    'pripustiť_si' => [
        [ 'k', 'telo' ],
    ],
    'pripísať' => [
        [ 'k', 'dobro' ],
    ],
    'priviesť' => [
        [ 'na', 'svet' ],
        [ 'navnivoč' ],
    ],
    'privádzať' => [
        [ 'na', 'svet' ],
    ],
    'prísť' => [
        [ 'k', 'slovo' ],
        [ 'skrátka' ],
        [ 'na', 'rad' ],
        [ 'na', 'chuť' ],
        [ 'vhod' ],
        [ 'na', 'svet' ],
        [ 'na', 'pomoc' ],
        [ 'reč' ],
        [ 'navnivoč' ],
        [ 'na', 'myseľ' ],
        [ 'na', 'program', 'deň' ],
        [ 'nazmar' ],
        [ 'ku', 'česť' ],
        [ 'na', 'pretras' ],
        [ 'k', 'seba' ],
        [ 'k', 'rozum' ],
    ],
    'pustiť' => [
        [ 'k', 'slovo' ],
        [ 'k', 'voda' ],
    ],
    'púšťanie' => [
        [ 'žila' ],
    ],
    'robiť' => [
        [ 'zlodej' ],
        [ 'dobrota' ],
        [ 'svoj' ],
        [ 'neplecha' ],
    ],
    'rozdať_si' => [
        [ 'ten' ],
    ],
    'rozhádzať_si' => [
        [ 'ten' ],
    ],
    'rozviazať' => [
        [ 'jazyk' ],
    ],
    'skloniť' => [
        [ 'hlava' ],
    ],
    'spadnúť' => [
        [ 'do', 'lono' ],
        [ 'z', 'nebo' ],
        [ 'z', 'višňa' ],
    ],
    'stratiť' => [
        [ 'z', 'dohľad' ],
        [ 'z', 'oko' ],
        [ 'z', 'dosluch' ],
        [ 'z', 'myseľ' ],
    ],
    'strácať' => [
        [ 'z', 'dohľad' ],
        [ 'z', 'myseľ' ],
    ],
    'stáť' => [
        [ 'čo', 'stáť' ],
    ],
    'sypať' => [
        [ 'z', 'rukáv' ],
    ],
    'sťahovať_sa' => [
        [ 'mrak' ],
    ],
    'tiahnuť' => [
        [ 'príklad' ],
    ],
    'trafiť' => [
        [ 'do', 'čierny' ],
        [ 'klinec', 'na', 'hlavička' ],
    ],
    'trvať' => [
        [ 'na', 'svoj' ],
    ],
    'tvrdiť' => [
        [ 'basa', 'muzika' ],
    ],
    'upútať' => [
        [ 'pozornosť' ],
    ],
    'urobiť' => [
        [ 'bodka' ],
        [ 'dobre' ],
        [ 'bankrot' ],
    ],
    'utnúť_sa' => [
        [ 'majster', 'tesár' ],
    ],
    'uviesť' => [
        [ 'na', 'miera', '(správny|pravý)' ],
        [ 'do', 'život' ],
    ],
    'uvádzať' => [
        [ 'do', 'život' ],
        [ 'na', 'miera', 'pravý' ],
    ],
    'uzrieť' => [
        [ 'svetlo', 'svet' ],
    ],
    'učiniť' => [
        [ 'zadosť' ],
        [ 'svoj' ],
        [ 'šťastie' ],
    ],
    'ušiť' => [
        [ 'na', 'miera' ],
        [ 'na', 'telo' ],
    ],
    'vedieť' => [
        [ 'svoj' ],
    ],
    'vedieť_si' => [
        [ 'rada' ],
    ],
    'vidieť' => [
        [ 'na', 'oko', 'vlastný' ],
    ],
    'viesť' => [
        [ 'život' ],
        [ 'reč' ],
        [ 'reč', 'hlúpy' ],
    ],
    'visieť' => [
        [ 'otáznik' ],
        [ 'ako', 'meč', 'Damokles' ],
    ],
    'vracať_sa' => [
        [ 'do', 'forma' ],
    ],
    'vybavovať' => [
        [ 'účet' ],
    ],
    'vychádzať' => [
        [ 'najavo' ],
    ],
    'vycucať_si' => [
        [ 'z', 'prst' ],
    ],
    'vydať' => [
        [ 'na', 'milosť', 'na', 'nemilosť' ],
        [ 'napospas' ],
        [ 'z-', 'seba' ],
    ],
    'vyhodiť_si' => [
        [ 'z', 'kopyto' ],
        [ 'z', 'kopýtko' ],
    ],
    'vyjsť' => [
        [ 'najavo' ],
        [ 'navrch' ],
    ],
    'vykonať' => [
        [ 'svoj' ],
    ],
    'vykopať' => [
        [ 'sekera', 'vojnový' ],
    ],
    'vymknúť_sa' => [
        [ 'z', 'ruka' ],
    ],
    'vypáliť' => [
        [ 'rybník' ],
    ],
    'vyraziť' => [
        [ 'dych' ],
    ],
    'vystrkovať' => [
        [ 'rožok' ],
    ],
    'vystupovať' => [
        [ 'na', 'povrch' ],
        [ 'do', 'popredie' ],
    ],
    'vytanúť' => [
        [ 'na', 'myseľ' ],
        [ 'pred', 'oko' ],
    ],
    'vyviesť' => [
        [ 'z', 'miera' ],
    ],
    'vyvolávať' => [
        [ 'v', 'život' ],
    ],
    'vzatie' => [
        [ 'do', 'väzba' ],
    ],
    'vziať' => [
        [ 'do', 'úvaha' ],
        [ 'do', 'väzba' ],
        [ 'na', 'vedomie' ],
        [ 'za', 'svoj' ],
        [ 'na', 'seba' ],
        [ 'do', 'ruka', '(môj|svoj)' ],
        [ 'do', 'ruka' ],
        [ 'zavďak' ],
        [ 'späť' ],
        [ 'naspäť' ],
        [ 'na', 'zreteľ' ],
        [ 'noha', 'na', 'plece' ],
        [ 'za', 'slovo' ],
        [ 'do', 'zajačí' ],
        [ 'na', 'milosť' ],
        [ 'roh' ],
        [ 'koniec', 'rýchly' ],
        [ 'do', 'ruka', 'svoj' ],
    ],
    'vziať_si' => [
        [ 'k', 'srdce' ],
        [ 'život' ],
        [ 'slovo' ],
        [ 'na', 'starosť' ],
        [ 'na', 'muška' ],
    ],
    'vztiahnuť' => [
        [ 'ruka' ],
        [ 'päsť' ],
    ],
    'výčitka' => [
        [ 'svedomie' ],
    ],
    'vŕtať' => [
        [ 'hlava' ],
    ],
    'zachovať' => [
        [ 'pri', 'život' ],
    ],
    'zamiesť' => [
        [ 'prah', 'vlastný' ],
        [ 'pred', 'prah', 'vlastný' ],
    ],
    'zanechať' => [
        [ 'napospas' ],
    ],
    'zaplatiť' => [
        [ 'pánboh' ],
    ],
    'zatajiť' => [
        [ 'dych' ],
    ],
    'zatajiť_sa' => [
        [ 'dych' ],
    ],
    'zatvoriť' => [
        [ 'ústa' ],
    ],
    'zavesiť_sa' => [
        [ 'na', 'krk' ],
    ],
    'zaviesť' => [
        [ 'reč' ],
    ],
    'zavrieť' => [
        [ 'ústa' ],
    ],
    'zažiť' => [
        [ 'na', 'koža', 'vlastný' ],
    ],
    'zhoda' => [
        [ 'okolnosť' ],
    ],
    'zlomiť' => [
        [ 'palica' ],
    ],
    'zložiť' => [
        [ 'ruka', 'do', 'klin' ],
    ],
    'zmeniť' => [
        [ 'k', 'dobrý' ],
    ],
    'zmietnuť' => [
        [ 'zo', 'stôl' ],
    ],
    'zohrať' => [
        [ 'rola' ],
        [ 'úloha' ],
    ],
    'zohrávať' => [
        [ 'rola' ],
        [ 'úloha' ],
    ],
    'zostať' => [
        [ 'sám' ],
    ],
    'zostávať' => [
        [ 'v', 'platnosť' ],
        [ 'pri', 'starý' ],
    ],
    'zožierať_sa' => [
        [ 'nuda' ],
    ],
    'zraziť' => [
        [ 'na', 'koleno' ],
        [ 'do', 'koleno' ],
    ],
    'zrovnať' => [
        [ 's', 'zem' ],
    ],
    'zájsť' => [
        [ 'do', 'krajnosť' ],
    ],
    'zísť' => [
        [ 'z', 'oko' ],
    ],
    'zívať' => [
        [ 'prázdnota' ],
    ],
    'zľahnúť' => [
        [ 'zem' ],
    ],
    'ísť' => [
        [ 'na', 'loď', 'rovnaký' ],
        [ 'ďalej' ],
        [ 'na', 'odbyt' ],
        [ 'do', 'tuhý' ],
        [ 'ruka', 'v', 'ruka' ],
        [ 'príklad' ],
        [ 'po', 'krk' ],
        [ 'tlstý', 'do', 'tenký' ],
        [ 'z', 'kopec' ],
        [ 's', 'cena' ],
        [ 'kĺzať', 'sa' ],
        [ '(dokopy|dohromady)' ],
        [ 'vzor' ],
        [ 'proti', 'prúd' ],
    ],
    'čakať' => [
        [ 'dieťa' ],
    ],
    'ľahnúť' => [
        [ 'popol' ],
    ],
    'šinúť_si' => [
        [ 'ten' ],
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
        my $matches         = 1;
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
        foreach my $adesc (@parts_to_adescs) {
            my (@tnodes) = $adesc->get_referencing_nodes('a/lex.rf');
            if (@tnodes) {
                map { $_->set_functor($functor) } @tnodes;
            }
        }

        log_info( $functor . ' MATCH: ' . $anode->lemma . ' + ' . join( ' ', @$parts ) . ': ' . $anode->get_address );
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
