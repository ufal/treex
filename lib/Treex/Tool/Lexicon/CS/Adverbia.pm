package Treex::Tool::Lexicon::CS::Adverbia;

use strict;
use warnings;
use utf8;

my %pronomadv;
map { $pronomadv{$_} = 1 } qw(
    dokdy dokud jak jakkoliv jaksi jakž kam kamkoliv kampak kamsi kde kdekoliv
    kdepak kdesi kdeže kdy kdykoli kdysi kudy leckde leckdy málokde málokdy
    navždy nějak někam někde někdy nijak nikam nikde nikdy odevšad odkdy odkud
    odněkud odnikud odsud onak onde onehdá pak poté potom potud proč proto sem
    tady taktéž takž tam tamhle tamtéž teď tudy tuhle tytam všudy vždy zde);

my %nongradableadv;
map { $nongradableadv{$_} = 1 } qw(
    akorát alespoň ani ani_tak asi aspoň až bezděčně bezesporu bezmála bezpochyby
    beztak bohudík bohužel bůhvíkdy celkem celkem_vzato cik_cak časem čas_od_času
    dejme_tomu díkybohu dnes docela dodnes doholaido_hola dohromady dojetím
    dokola dokonce dokořán doleva dom doma domů donedávna donekonečna doopravdy
    dopodrobna dopoledne doprava doprostřed dopředu dost dosud dosyta doširoka
    doteď doufám doufejme do_úmoru dovnitř dozadu dozajista druhdy dvaapůlkrát
    dvakrát furt hned horempádem chtě_nechtě chtíc_nechtíc chválabohu chvílemi
    i ihned jakkoliv jaksepatří jakž jednou jednou_provždy jen_co_je_pravda
    jenom ještě ještě_více jinak jinam jinde jindy jinudy již kampak kamsi každopádně
    kdekoliv kdepak kdesi kdeže kdovíjak kleče kolem kolem_dokola koneckonců
    křížem_krážem kupodivu kupředu kupříkladu kvapem ladem leckde leckdy letos
    leže líto loni málem mezitím mimo mimoděk mimochodem mimoto místy mlčky
    mnohde mnohem mnohokrát myslím nabíledni naboso načas načase načerno nadále
    nadarmo nadlouhoina_dlouho nadobro nadto nadvakrát nahlas náhodou nahoru
    nahoře najednou najevo najisto nakolik nakonec nakrátkoina_krátko nakřivo
    nalevo námahou namále namátkou naměkko namístě nanejvýš naneštěstí nanovo
    naoko naopak naostro napevno napilno naplno napodruhé napolo napoprvé naposled
    napospas napotřetí napovrch napravo naprázdno naprosto naproti napřed napřesrok
    například napříště naráz naruby narychlo naschvál nasnadě nastojato naštěstí
    nato natolik natruc natrvalo natřikrát natvrdo navečer navěkyina_věky navenek
    navíc navrch navýsost navzájem navzdory nazítří nazmar nazpátek naživu ne
    nedbaje nedej_Bůh nehledě nechtě nejdříve nejen nejpozději nejprve nejspíš
    nejvýše několikrát nemluvě nepočítaje nepříliš neřku nevědomky nevyjímaje
    nicméně nikdá nikoliv nikterak nóbl nyní občas obzvlášť odedávna odevšad
    odhadem odjakživa odjinud odnikud od_oka odpoledne omylem onak onde onehdá
    opět opodál opravdu ostatně ovšem ovšemže pěšky poblíž počítaje podomácku
    podruhé pohromadě pohříchu pojednou pokaždé ponejprv ponejvíce poněkolikáté
    poněkud popořádkuipo_pořádku popravdě popřípadě pořád posavad poskrovnu
    poslechněte posléze potají potažmo potmě potud pouze povýtce pozadu pozítří
    poznenáhlu pozpátku pozvolna pranic právě právem právě_tak proboha promiňte
    propříště prosím protentokrát provždy prozatím prý pryč přece přece_jen
    předem předevčírem především předloni předtím přesčas přespříliš přesto
    příliš přinejhorším přinejmenším přitom rádoby ráno respektive rovněž rovnou
    rušno sebelépe sem_tam seshora shůry sice skoro snad sotva soudě stěží strachem
    stranou středem střemhlav široce šmahem štěstím tak také tak_jako_tak tak_říkaje
    takřka taktéž takto takž tamhle tamtéž tedy tehdy téměř tenkrát tentokrát
    teprve též tím_méně tím_spíše tolik toliko totiž trochu třeba tudíž tuhle
    tuším tytam uprostřed už vabank vcelku včas včera včetně večer vedle ven
    venku věřím věřte veskrze vesměs většinou vhod víceméně víte vlastně vlevo
    vloni vniveč v_podstatě vpodvečer vpravdě vpravo vpřed vpředu vsedě vskutku
    vstávaje_lehaje vstoje všanc všehovšudy všude všudy vůbec vycházeje vyjímaje
    vzadu vzápětí v_zásadě vzhůru vždyť zadarmo zadem zadobře zadost zahrnuje
    záhy zajedno zajisté zakrátko zamladaiza_mlada zanedlouho zaplať_Pánbůh
    zapotřebí zaprvé zároveň zase zatím zavděk závěrem zázrakem zaživa zblízka
    zbrusu zcela zčásti zčistajasna zdaleka zdola zejména zevnitř zezadu zhola
    zhruba zhusta zítra zjara zkrátka zkusmo zlehka zleva znenadání zničehonic
    znovu zostra zpaměti zpátky zpočátkuiz_počátku zpravidla zprvu zrovna zřídka
    ztěžka zticha zuby_nehty zvenčí zvenku zvlášť zvnějšku zvolna);

my %notnegableadv;
map { $notnegableadv{$_} = 1 } qw(
    abecedně abnormálně akorát alegoricky alespoň alikvótně analogicky ani ani_tak
    antikomunisticky aprioristicky archetypálně asi asketicky aspoň astmaticky
    až báječně bedlivě bezcelně bezděčně bezdrátově bezdůvodně bezesporu bezhlavě
    bezhlesně bezchybně bezkonkurenčně bezmála bezmezně bezmocně bezmyšlenkovitě
    beznadějně bezpečnostně bezplatně bezpodmínečně bezpochyby bezproblémově
    bezprostředně bezradně beztak beztrestně bezúplatně bezúročně bezúspěšně
    bezvládně bezvýhradně bezvýsledně bídně bigbítově biograficky bizarně blahobytně
    bláznivě blbě bledě bleskově bohudík bohužel bombasticky bouřlivě branně
    bravurně brilantně briskně brzy bůhvíkdy bystře bytostně celkem celkem_vzato
    celkově celoročně celostátně celosvětově cik_cak církevně citově cynicky
    časem časně časopisecky částečně čecháčkovsky čerstvě červenobíle čiperně
    číslicově čtenářsky čtvrtletně čtyřnásobně dál dálkově dekadentně denně
    dennodenně desetinásobně detailně diametrálně díkybohu disciplinárně dlouhodobě
    dnes dobromyslně docela dodatečně dodnes doholaido_hola dohromady dojemně
    dokdy dokola dokonce dokořán doktrinárně dokud dole doleva dolů dom domněle
    domů donedávna donekonečna doopravdy dopodrobna dopoledne doprava doprostřed
    dopředu doslova doslovně dosud dosyta doširoka doteď dovnitř dozadu dozajista
    doživotně dramaturgicky drasticky druhdy druhotně dříve duševně dutě dvaapůlkrát
    dvakrát dvojjazyčně dvojnásob dvořákovsky dvoukolově dychtivě dylanovsky
    ebenově enormně evidentně excelentně excentricky existenčně exponenciálně
    externě fakticky faktograficky familiérně famózně fixně flagrantně folklorně
    foneticky formulačně frontálně furt fyzikálně geometricky gólově goticky
    hazardérsky herně hladce hladově hlasově hned hněvivě hodně horce horempádem
    horlivě hořce houževnatě hravě hromadně hrozivě hrozně hutně hypoteticky
    chladně chladno chlapecky chrabře chronologicky chtě_nechtě chtíc_nechtíc
    chválabohu chvílemi chybně i ihned ikonologicky ilegálně informačně instinktivně
    intelektově interně ironicky jak jakkoliv jaksepatří jaksi jakž jedině jednohlasně
    jednomyslně jednorázově jednostranně jednostrunně jemně jen_co_je_pravda
    ještě ještě_více jihovýchodně jihozápadně jinam jindy jinudy již jižně jmenovitě
    kacířsky kam kamkoliv kampak kamsi kapacitně kapitálově kategoricky každopádně
    každoročně kde kdekoliv kdepak kdesi kdeže kdovíjak kdy kdykoli kdysi kladně
    klamavě klaunsky kleče klimaticky kolem kolmo komorně kompetenčně kompozičně
    koneckonců konstrukčně kontraktačně kontumačně krajně krásně krátce kratičce
    krátkodobě krutě křížem_krážem kudy kulantně kupodivu kuponově kupředu kupříkladu
    kuriózně kvapem kvapně kyvadlově laboratorně ladem laicky lajdácky lakonicky
    lapidárně leckde leckdy ledově legračně lehkomyslně lehounce letmo letos
    lexikálně leže libovolně liknavě líně líto loni málem maličko málokde málokdy
    markantně marketingově marně masajsky měkce mělce mentálně meritorně měsíčně
    metodologicky meziměsíčně meziročně mezitím mimo mimoděk mimochodem mimořádně
    mimoto minimálně minule mistrně místy mizerně mlčenlivě mlčky mlhavě mnohde
    mnohdy mnohem mnohokrát mnohomluvně mnohonásobně mnohovrstevně moc mocensky
    mocně modře mohutně momentálně monetálně monotematicky moralisticky morfologicky
    myšlenkově nabíledni naboso nacionálně načas načase načerno nadále nadarmo
    nádherně nadlouhoina_dlouho nadměrně nadneseně nadobro nadprůměrně nadstandardně
    nadto nadvakrát nahlas náhodou nahoru nahoře najednou najevo najisto nakolik
    nakonec nakrátkoina_krátko nakřivo naléhavě nalevo námahou namále namátkou
    naměkko namístě nanejvýš naneštěstí nanovo naoko naopak naostro napevno
    napilno naplno napodruhé napolo napoprvé naposled napospas napotřetí napovrch
    napravo naprázdno naprosto naproti napřed napřesrok například napříště naráz
    narkoticky národnostně naruby narychlo naschvál následně následovně nasnadě
    nastojato naštěstí nato natolik natruc natrvalo natřikrát natvrdo navečer
    navěkyina_věky navenek navíc navrch navýsost navzájem navzdory navždy nazítří
    nazmar názorově nazpátek naživu ne nečekaně nedávno nedbaje nedbale negativně
    nehledě nehorázně nechtě nějak nejdříve někam někde někdy několikanásobně
    několikrát neměně nemluvě nenadále nenávratně neodbytně neoddiskutovatelně
    neodkladně neodlučně nepatrně nepočítaje nepochybně neprodleně nepřeberně
    nerozlučně nervózně nesčetně neskonale nesmírně nesmyslně nestranně neúnavně
    neustále neutrálně nevyjímaje nezvykle nicméně nijak nikam nikdá nikde nikdy
    nikoliv nikterak nízko nóbl noblesně nostalgicky notářsky notně notoricky
    nouzově nudně nyní občas obdivně obdivuhodně obdobně obecně objevně oblačno
    obludně oboustranně obráceně obranně obrazově obrovsky obsahově obzvlášť
    očividně odedávna odevšad odhadem odjakživa odjinud odkdy odkud odlišně
    odloučeně odmítavě odněkud odnikud od_oka odpoledne odsud odtažitě ohnivě
    ohromně ochotnicky ojediněle okamžitě okatě okrajově okupačně omylem onak
    onde onehdá opačně opět opětovně opodál opožděně opravdu oranžově osminásobně
    ostatně osudově ošklivě otrocky ovšem ovšemže pádně pak palčivě parádně
    paradoxně paralelně pasivně patentově permanentně perně personálně pesimisticky
    pěšky pěvecky pikantně pirátsky planě planetárně plasticky plebejsky pobaveně
    poblíž podivně podloudně podomácku podrobně podruhé podvědomě pofidérně
    pohrdavě pohrdlivě pohromadě pohříchu pojednou pokaždé pokoutně polohově
    polojasno polopaticky polystylově pomalu ponejprv ponejvíce poněkolikáté
    poněkud popořádkuipo_pořádku popravdě popřípadě pořád posavad poskrovnu
    posléze posluchačsky posměšně posmrtně postupně posupně pošetile potají
    potažmo poté potenciálně potichu potmě potom poťouchle potud pouze povahově
    povážlivě povrchově povýtce pozadu pozdě pozitivně pozítří poznenáhlu pozpátku
    pozvolna pracně pranic právě právě_tak pregnantně preventivně proboha procentuálně
    proč profesorsky prohibitně projektově promptně propříště prostě prostředně
    protentokrát protestantsky protestně protibakteriálně protiinflačně protikladně
    protikomunisticky protinacisticky protiněmecky protiprávně protiústavně
    protiválečně protizákonně proto provinile provizorně provokativně provždy
    prozatím prý pryč přece přece_jen předběžně předčasně předem předevčírem
    především předloni předně přednostně předtím přemrštěně přesčas přespříliš
    přesto převážně převelice přibližně příjmově příležitostně přinejhorším
    přinejmenším přísně příště přitom psychicky rádoby raně ráno rapidně razantně
    rázně redakčně rekordně rekreačně relativně resortně respektive restriktivně
    rezolutně riskantně ročně rovněž rovnou rozechvěle rozhořčeně rozkošně rozšafně
    roztomile rozverně rozvroucněně ručně rušno různě rychle řádově řečnicky
    řemeslně řetězovitě samočinně samoúčelně samozvaně sarkasticky satiricky
    sebelépe sebevražedně sedminásobně sem sem_tam seshora setrvačně severně
    severozápadně shrnutě shůry schválně sice silně skandovaně skepticky skoro
    skvěle skvostně slabě slepě sluchově snad sólově sotva souborně soudě souhrnně
    spíše sponzorsky sporadicky spoře staročesky stěží stonásobně stoprocentně
    strachem stranou strašlivě strašně striktně strojně stručně středem středně
    střelecky střemhlav střídavě stupňovitě surově suše svahilsky svérázně sveřepě
    světle svévolně svisle svižně svobodomyslně syrově šalamounsky šedě šikmo
    škaredě šmahem šokovaně špičkově štěstím tabulkově tady tak také tak_jako_tak
    tak_říkaje takřka taktéž takto takzvaně takž tam tamhle tamtéž taxativně
    teď tedy teenagersky tehdy telefonicky televizně téměř temně tenkrát tentokrát
    tepelně teprve též tím_méně tím_spíše tolik toliko totálně totiž transdisciplinárně
    trapně tréninkově trestuhodně triumfálně trochu trojnásobně trpce trpně
    trvale třeba tudíž tudy tuhle tvrdě tvrdošíjně tytam údajně uhrančivě úhrnně
    úlevně úlisně umně univerzálně uprostřed upřeně urbionalisticky urychleně
    úsečně usilovně ustavičně ústně uvnitř úzce územně územněsprávně úzkostlivě
    úzkostně už vančurovsky varovně vcelku včas včera večer věčně vedle vehementně
    věkově velmi ven venku vertikálně veřejnoprávně veskrze vesměs většinou
    více víceméně víceúčelově virtuózně vítězně vlastně vlastnoručně vlažně
    vlevo vloni vnějškově vnitropoliticky vnitřně vniveč vodivě vodorovně vokálně
    v_podstatě vpodvečer vpravdě vpravo vpřed vpředu vratce vrcholně vrcholově
    vřele vsedě vskutku vstoje všanc všehovšudy všelijak všestranně všude všudy
    vůbec vulgárně výborně výdajově výhledově vycházeje vypjatě výrazově výsledně
    výtečně vytrženě vzadu vzájemně vzápětí v_zásadě vzdáleně vzhledově vzhůru
    vzorně vždy vždyť zadarmo zadem zadobře zadost zahraničně záhy zajedno zajisté
    zakrátko zakřiknutě zálibně zálohově zamladaiza_mlada zamračeně zanedlouho
    západně zaplať_Pánbůh zapotřebí zaprvé zároveň zarytě zásadně zase zatím
    zatraceně zavděk závěrem závratně zázračně zázrakem zaživa zběsile zblízka
    zbrkle zbrusu zbytečně zcela zčásti zčistajasna zdaleka zdánlivě zde zděšeně
    zdlouhavě zdola zejména zelenobíle zevnitř zevrubně zezadu zhola zhruba
    zhusta zítra zjara zkoumavě zkrátka zkusmo zlatavě zlehka zleva zlobně zlomyslně
    zlověstně značně znamenitě znechuceně znenadání zničehonic znovu zostra
    zoufale zpaměti zpátky zpětně zpočátkuiz_počátku zpravidla zpropadeně zprvu
    zpupně zrakově zrcadlově zrovna zřejmě ztepile ztěžka zticha zvenčí zvenku
    zvlášť zvláštně zvnějšku zvolna zvukově žalostně žánrově žíznivě);

sub is_negable {
    my $adv = shift;
    return 0 if $notnegableadv{$adv};
    return 1;
}

sub is_gradable {
    my $adv = shift;
    return 0 if $nongradableadv{$adv};
    return 1;
}

sub is_pronom {
    my $adv = shift;
    return 1 if $pronomadv{$adv};
    return 0;
}

# tohle je velmi tupe, pole by se melo omezit jen na ty, ktere nejdou odvodit pravidelne (tezce-tezky)
my %adv2adj;
map { my ($j, $r) = split '-', $_; $adv2adj{$r} = $j } qw(
    abecedně-abecední abnormálně-abnormální absolutně-absolutní abstraktně-abstraktní
    absurdně-absurdní adekvátně-adekvátní adresně-adresný agresivně-agresivní
    akademicky-akademický aktivně-aktivní alegoricky-alegorický alibisticky-alibistický
    alikvótně-alikvótní amatérsky-amatérský americky-americký analogicky-analogický
    andělsky-andělský anglicky-anglický anonymně-anonymní antikomunisticky-antikomunistický
    antisemitsky-antisemitský aprioristicky-aprioristický apriorně-apriorní
    archetypálně-archetypální asketicky-asketický astmaticky-astmatický autenticky-autentický
    automaticky-automatický autoritativně-autoritativní báječně-báječný banálně-banální
    barevně-barevný barvitě-barvitý bedlivě-bedlivý bezcelně-bezcelní bezdrátově-bezdrátový
    bezdůvodně-bezdůvodný bezhlavě-bezhlavý bezhlesně-bezhlesný bezchybně-bezchybný
    bezkonkurenčně-bezkonkurenční bezmezně-bezmezný bezmocně-bezmocný bezmyšlenkovitě-bezmyšlenkovitý
    beznadějně-beznadějný bezpečně-bezpečný bezpečnostně-bezpečnostní bezplatně-bezplatný
    bezpodmínečně-bezpodmínečný bezproblémově-bezproblémový bezprostředně-bezprostřední
    bezradně-bezradný beztrestně-beztrestný bezúplatně-bezúplatný bezúročně-bezúročný
    bezúspěšně-bezúspěšný bezvládně-bezvládný bezvýhradně-bezvýhradný bezvýsledně-bezvýsledný
    běžně-běžný bídně-bídný bigbítově-bigbítový bíle-bílý biograficky-biografický
    biologicky-biologický bizarně-bizarní blahobytně-blahobytný bláznivě-bláznivý
    blbě-blbý bledě-bledý bleskově-bleskový bohatě-bohatý bolestivě-bolestivý
    bombasticky-bombastický bouřlivě-bouřlivý branně-branný bravurně-bravurní
    brilantně-brilantní briskně-briskní brutálně-brutální bystře-bystrý bytostně-bytostný
    bývale-bývalý cele-celý celkově-celkový celoročně-celoroční celostátně-celostátní
    celosvětově-celosvětový cenově-cenový centrálně-centrální cílevědomě-cílevědomý
    církevně-církevní citelně-citelný citlivě-citlivý citově-citový civilně-civilní
    cudně-cudný cynicky-cynický časně-časný časopisecky-časopisecký časově-časový
    částečně-částečný čecháčkovsky-čecháčkovský čerstvě-čerstvý červenobíle-červenobílý
    česky-český čestně-čestný čiperně-čiperný číslicově-číslicový čistě-čistý
    čítankově-čítankový čitelně-čitelný čtenářsky-čtenářský čtvrtletně-čtvrtletní
    čtyřnásobně-čtyřnásobný dalece-daleký dálkově-dálkový daňově-daňový definitivně-definitivní
    dekadentně-dekadentní delikátně-delikátní demagogicky-demagogický demokraticky-demokratický
    denně-denní dennodenně-dennodenní desetinásobně-desetinásobný destruktivně-destruktivní
    detailně-detailní dětsky-dětský diametrálně-diametrální diferencovaně-diferencovaný
    digitálně-digitální diplomaticky-diplomatický disciplinárně-disciplinární
    disciplinovaně-disciplinovaný diskrétně-diskrétní diskriminačně-diskriminační
    diskursivně-diskursivní divácky-divácký divadelně-divadelní divoce-divoký
    dlouho-dlouhý dlouhodobě-dlouhodobý dlouze-dlouhý dobromyslně-dobromyslný
    dobrovolně-dobrovolný dobře-dobrý dočasně-dočasný dodatečně-dodatečný dojemně-dojemný
    dokonale-dokonalý doktrinárně-doktrinární domněle-domnělý doslovně-doslovný
    dostatečně-dostatečný dotčeně-dotčený dovedně-dovedný doživotně-doživotní
    draho-drahý dramaticky-dramatický dramaturgicky-dramaturgický drasticky-drastický
    draze-drahý dráždivě-dráždivý drogově-drogový drsně-drsný druhotně-druhotný
    duchovně-duchovní důkladně-důkladný důležitě-důležitý důmyslně-důmyslný
    důrazně-důrazný důsledně-důsledný důstojně-důstojný duševně-duševní dutě-dutý
    důvěrně-důvěrný důvodně-důvodný dvojjazyčně-dvojjazyčný dvojnásob-dvojnásobný
    dvojnásobně-dvojnásobný dvořákovsky-dvořákovský dvoukolově-dvoukolový dychtivě-dychtivý
    dylanovsky-dylanovský dynamicky-dynamický ebenově-ebenový efektivně-efektivní
    efektně-efektní ekologicky-ekologický ekonomicky-ekonomický elegantně-elegantní
    elektricky-elektrický elitářsky-elitářský emocionálně-emocionální energeticky-energetický
    energicky-energický enormně-enormní eroticky-erotický erudovaně-erudovaný
    esteticky-estetický eticky-etický etnicky-etnický eventuálně-eventuální
    evidentně-evidentní evropsky-evropský excelentně-excelentní excentricky-excentrický
    existenčně-existenční exkluzivně-exkluzivní exoticky-exotický experimentálně-experimentální
    exponenciálně-exponenciální exportně-exportní externě-externí extrémně-extrémní
    fakticky-faktický faktograficky-faktografický falešně-falešný familiérně-familiérní
    famózně-famózní fantasticky-fantastický fašisticky-fašistický fatálně-fatální
    feministicky-feministický fér-férový férově-férový filozoficky-filozofický
    finančně-finanční fixně-fixní flagrantně-flagrantní flegmaticky-flegmatický
    folklorně-folklórní foneticky-fonetický formálně-formální formulačně-formulační
    francouzsky-francouzský frontálně-frontální funkčně-funkční fyzicky-fyzický
    fyzikálně-fyzikální galantně-galantní generačně-generační geometricky-geometrický
    globálně-globální gólově-gólový goticky-gotický graficky-grafický gramaticky-gramatický
    halasně-halasný hazardérsky-hazardérský herecky-herecký herně-herní hezky-hezký
    historicky-historický hladce-hladký hladově-hladový hlasitě-hlasitý hlasově-hlasový
    hlavně-hlavní hluboce-hluboký hluboko-hluboký hlučně-hlučný hmotně-hmotný
    hněvivě-hněvivý hodnotově-hodnotový hojně-hojný horce-horký horečně-horečný
    horlivě-horlivý hořce-hořký hospodárně-hospodárný hospodářsky-hospodářský
    hotově-hotový houfně-houfný houževnatě-houževnatý hravě-hravý hrdě-hrdý
    hromadně-hromadný hrozivě-hrozivý hrozně-hrozný hrubě-hrubý hudebně-hudební
    humorně-humorný hutně-hutný hygienicky-hygienický hypoteticky-hypotetický
    chaoticky-chaotický chladně-chladný chladno-chladný chlapecky-chlapecký
    chrabře-chrabrý chronologicky-chronologický chtěně-chtěný chvalně-chvalný
    chybně-chybný chytře-chytrý ideálně-ideální ideologicky-ideologický ideově-ideový
    ikonologicky-ikonologický ilegálně-ilegální individuálně-individuální informačně-informační
    informativně-informativní informovaně-informovaný instinktivně-instinktivní
    intelektově-intelektový intelektuálně-intelektuální intenzivně-intenzívní
    intenzívně-intenzívní interně-interní intimně-intimní invenčně-invenční
    investičně-investiční ironicky-ironický janáčkovsky-janáčkovský jasně-jasný
    jasno-jasný jazykově-jazykový jedině-jediný jednoduše-jednoduchý jednohlasně-jednohlasný
    jednolitě-jednolitý jednomyslně-jednomyslný jednorázově-jednorázový jednostranně-jednostranný
    jednostrunně-jednostrunný jednotlivě-jednotlivý jednotně-jednotný jednoznačně-jednoznačný
    jemně-jemný jihovýchodně-jihovýchodní jihozápadně-jihozápadní jistě-jistý
    jižně-jižní jmenovitě-jmenovitý kacířsky-kacířský kapacitně-kapacitní kapitálově-kapitálový
    kategoricky-kategorický každodenně-každodenní každoročně-každoroční kladně-kladný
    klamavě-klamavý klasicky-klasický klaunsky-klaunský klidně-klidný klimaticky-klimatický
    kmenově-kmenový knižně-knižní kolektivně-kolektivní kolmo-kolmý komediálně-komediální
    komerčně-komerční komicky-komický komorně-komorní kompaktně-kompaktní kompetenčně-kompetenční
    kompetentně-kompetentní kompletně-kompletní komplexně-komplexní kompozičně-kompoziční
    koncepčně-koncepční konečně-konečný konfrontačně-konfrontační konkrétně-konkrétní
    konstantně-konstantní konstrukčně-konstrukční kontraktačně-kontraktační
    kontrastně-kontrastní kontrolovaně-kontrolovaný kontumačně-kontumační korektně-korektní
    kovově-kovový kradmo-kradmý krajně-krajní krásně-krásný krátce-krátký kratičce-kratičký
    krátko-krátký krátkodobě-krátkodobý kriticky-kritický krutě-krutý krvavě-krvavý
    křečovitě-křečovitý křesťansky-křesťanský kulantně-kulantní kultivovaně-kultivovaný
    kulturně-kulturní kuponově-kuponový kuriózně-kuriózní kvalifikovaně-kvalifikovaný
    kvalitativně-kvalitativní kvalitně-kvalitní kvantitativně-kvantitativní
    kvapně-kvapný kyvadlově-kyvadlový laboratorně-laboratorní lacině-laciný
    lacino-laciný laicky-laický lajdácky-lajdácký lakonicky-lakonický lapidárně-lapidární
    laskavě-laskavý ledově-ledový legálně-legální legislativně-legislativní
    legitimně-legitimní legračně-legrační lehce-lehký lehko-lehký lehkomyslně-lehkomyslný
    lehounce-lehounký letecky-letecký levicově-levicový levně-levný lexikálně-lexikální
    libě-libý liberálně-liberální libovolně-libovolný lidově-lidový liknavě-liknavý
    líně-líný logicky-logický maďarsky-maďarský maličko-maličký málo-malý manuálně-manuální
    markantně-markantní marketingově-marketingový marně-marný masajsky-masajský
    masivně-masivní masově-masový materiálně-materiální maximálně-maximální
    mechanicky-mechanický měkce-měkký mělce-mělký melodicky-melodický mentálně-mentální
    meritorně-meritorní měsíčně-měsíční metodicky-metodický metodologicky-metodologický
    meziměsíčně-meziměsíční mezinárodně-mezinárodní meziročně-meziroční mile-milý
    militantně-militantní milosrdně-milosrdný mimořádně-mimořádný minimálně-minimální
    minule-minulý mírně-mírný místně-místní mistrně-mistrný mistrovsky-mistrovský
    mizerně-mizerný mlčenlivě-mlčenlivý mlhavě-mlhavý mnohomluvně-mnohomluvný
    mnohonásobně-mnohonásobný mnohovrstevně-mnohovrstevný mocensky-mocenský
    mocně-mocný moderně-moderní módně-módní modře-modrý mohutně-mohutný momentálně-momentální
    monetálně-monetální monolitně-monolitní monotematicky-monotematický moralisticky-moralistický
    morálně-morální morfologicky-morfologický moudře-moudrý možná-možný mravně-mravní
    mylně-mylný myšlenkově-myšlenkový nábožensky-náboženský nacionalisticky-nacionalistický
    nacionálně-nacionální nadějně-nadějný nádherně-nádherný nadměrně-nadměrný
    nadmíru-nadměrný nadneseně-nadnesený nadprůměrně-nadprůměrný nadstandardně-nadstandardní
    nadšeně-nadšený náhle-náhlý nahodile-nahodilý náhodně-náhodný naivně-naivní
    naléhavě-naléhavý náležitě-náležitý nápaditě-nápaditý nápadně-nápadný narativně-narativní
    narkoticky-narkotický národně-národní národnostně-národnostní násilně-násilný
    následně-následný následovně-následovný názorně-názorný názorově-názorový
    nečekaně-nečekaný nečinně-nečinný nedávno-nedávný nedbale-nedbalý negativně-negativní
    nehorázně-nehorázný nechtěně-nechtěný nějak-nějaký několikanásobně-několikanásobný
    nekompromisně-kompromisní německy-německý neměně-neměnný nenávratně-nenávratný
    neobyčejně-neobyčejný neočekávaně-neočekávaný neodbytně-neodbytný neoddiskutovatelně-neodiskutovatelný
    neodkladně-neodkladný neodlučně-neodlučný neodmyslitelně-neodmyslitelný
    neodolatelně-neodolatelný neodůvodnitelně-neodůvodnitelný neodvratně-neodvratný
    neohroženě-neohrožený neomylně-neomylný neopakovatelně-neopakovatelný neotřele-neotřelý
    neovladatelně-neovladatelný nepatrně-nepatrný nepochybně-nepochybný nepokrytě-nepokrytý
    nepopiratelně-nepopiratelný nepopsatelně-nepopsatelný nepotlačitelně-nepotlačitelný
    nepozorovaně-nepozorovaný neprodleně-neprodlený nepřeberně-nepřeberný nepřehlédnutelně-nepřehlédnutelný
    nepřetržitě-nepřetržitý nepřítomně-nepřítomný nerozhodně-nerozhodný nerozlučně-nerozlučný
    nerušeně-nerušený nervózně-nervózní nesčetně-nesčetný neskonale-neskonalý
    neskutečně-neskutečný nesmírně-nesmírný nesmyslně-nesmyslný nesouměřitelně-nesouměřitelný
    nesporně-nesporný nesrovnatelně-nesrovnatelný nestranně-nestranný neúnavně-neúnavný
    neustále-neustálý neústupně-neústupný neutrálně-neutrální neuvěřitelně-neuvěřitelný
    nevěřícně-nevěřícný nevinně-nevinný nevyhnutelně-nevyhnutelný nevysvětlitelně-nevysvětlitelný
    nezadržitelně-nezadržitelný nezaměnitelně-nezaměnitelný nezávisle-nezávislý
    nezbytně-nezbytný nezvratně-nezvratný nezvykle-nezvyklý něžně-něžný nízko-nízký
    noblesně-noblesní normálně-normální nostalgicky-nostalgický notářsky-notářský
    notně-notný notoricky-notorický nouzově-nouzový nově-nový nuceně-nucený
    nudně-nudný nutně-nutný občansky-občanský obdivně-obdivný obdivuhodně-obdivuhodný
    obdobně-obdobný obecně-obecný obezřetně-obezřetný obchodně-obchodní objektivně-objektivní
    objevně-objevný oblačno-oblačný obludně-obludný oborově-oborový oboustranně-oboustranný
    obráceně-obrácený obranně-obranný obratně-obratný obrazně-obrazný obrazově-obrazový
    obrovsky-obrovský obsáhle-obsáhlý obsahově-obsahový obtížně-obtížný obvykle-obvyklý
    obyčejně-obyčejný očividně-očividný odborně-odborný odděleně-oddělený odlišně-odlišný
    odloučeně-odloučený odmítavě-odmítavý odpovědně-odpovědný odtažitě-odtažitý
    odůvodněně-odůvodněný odvážně-odvážný oficiálně-oficiální ohleduplně-ohleduplný
    ohnivě-ohnivý ohromně-ohromný ochotně-ochotný ochotnicky-ochotnický ojediněle-ojedinělý
    okamžitě-okamžitý okatě-okatý okázale-okázalý okrajově-okrajový okupačně-okupační
    omezeně-omezený opačně-opačný opakovaně-opakovaný opatrně-opatrný operativně-operativní
    opětně-opětný opětovně-opětovný opodstatněně-opodstatněný opožděně-opožděný
    opravdově-opravdový oprávněně-oprávněný optimálně-optimální optimisticky-optimistický
    oranžově-oranžový organizačně-organizační originálně-originální ortodoxně-ortodoxní
    osminásobně-osminásobný osobně-osobní ostře-ostrý osudově-osudový ošklivě-ošklivý
    otevřeně-otevřený otrocky-otrocký oulisně-úlisný ozdobně-ozdobný pádně-pádný
    palčivě-palčivý památkově-památkový papírově-papírový parádně-parádní paradoxně-paradoxní
    paralelně-paralelní pasivně-pasivní patentově-patentový pateticky-patetický
    patrně-patrný patřičně-patřičný paušálně-paušální pečlivě-pečlivý pejorativně-pejorativní
    pěkně-pěkný perfektně-perfektní periodicky-periodický permanentně-permanentní
    perně-perný personálně-personální perspektivně-perspektivní pesimisticky-pesimistický
    pestře-pestrý pěvecky-pěvecký pevně-pevný pietně-pietní pikantně-pikantní
    pilně-pilný pirátsky-pirátský písemně-písemný planě-planý planetárně-planetární
    plasticky-plastický platově-platový plebejsky-plebejský plně-plný plno-plný
    plnohodnotně-plnohodnotný plošně-plošný plynule-plynulý pobaveně-pobavený
    poctivě-poctivý počítačově-počítačový podbízivě-podbízivý podezřele-podezřelý
    podivně-podivný podloudně-podloudný podloženě-podložený podmínečně-podmínečný
    podmíněně-podmíněný podobně-podobný podrobně-podrobný podstatně-podstatný
    podvědomě-podvědomý pofidérně-pofidérní pohádkově-pohádkový pohlavně-pohlavní
    pohodlně-pohodlný pohotově-pohotový pohrdavě-pohrdavý pohrdlivě-pohrdlivý
    pohyblivě-pohyblivý pochopitelně-pochopitelný pochvalně-pochvalný pochybně-pochybný
    pokojně-pokojný pokorně-pokorný pokoutně-pokoutný politicky-politický polohově-polohový
    polojasno-polojasný polopaticky-polopatický polystylově-polystylový pomalu-pomalý
    poměrně-poměrný populárně-populární populisticky-populistický porovnatelně-porovnatelný
    pořádně-pořádný posledně-poslední posluchačsky-posluchačský poslušně-poslušný
    posměšně-posměšný posmrtně-posmrtný postmodernisticky-postmodernistický
    postupně-postupný posupně-posupný pošetile-pošetilý potenciálně-potenciální
    potěšitelně-potěšitelný poťouchle-poťouchlý poučeně-poučený poutavě-poutavý
    povahově-povahový povážlivě-povážlivý povědomě-povědomý povinně-povinný
    povrchově-povrchový pozitivně-pozitivní pozorně-pozorný pozoruhodně-pozoruhodný
    pracně-pracný pracovně-pracovní pragmaticky-pragmatický prakticky-praktický
    pravděpodobně-pravděpodobný pravicově-pravicový pravidelně-pravidelný právně-právní
    pravomocně-pravomocný pravopisně-pravopisný pregnantně-pregnantní preventivně-preventivní
    principiálně-principiální problematicky-problematický procentuálně-procentuální
    profesionálně-profesionální profesně-profesní profesorsky-profesorský programově-programový
    progresivně-progresivní prohibitně-prohibitní projektově-projektový prokazatelně-prokazatelný
    proklamativně-proklamativní proloženě-proložený promptně-promptní promyšleně-promyšlený
    propagandisticky-propagandistický proporcionálně-proporcionální prospěšně-prospěšný
    prostě-prostý prostorově-prostorový prostředně-prostřední protestantsky-protestantský
    protestně-protestní protibakteriálně-protibakteriální protiinflačně-protiinflační
    protikladně-protikladný protikomunisticky-protikomunistický protinacisticky-protinacistický
    protiněmecky-protiněmecký protiprávně-protiprávní protiústavně-protiústavní
    protiválečně-protiválečný protizákonně-protizákonný protokolárně-protokolární
    provinile-provinilý provizorně-provizorní provokativně-provokativní prozaicky-prozaický
    prozíravě-prozíravý průběžně-průběžný prudce-prudký průhledně-průhledný
    průměrně-průměrný průmyslově-průmyslový průrazně-průrazný průzračně-průzračný
    pružně-pružný přátelsky-přátelský předběžně-předběžný předčasně-předčasný
    předně-přední přednostně-přednostní přehledně-přehledný přehnaně-přehnaný
    přechodně-přechodný překvapeně-překvapený překvapivě-překvapivý přemrštěně-přemrštěný
    přeneseně-přenesený přerývaně-přerývaný přesně-přesný přesvědčivě-přesvědčivý
    převážně-převážný převelice-převeliký převratně-převratný přibližně-přibližný
    příjemně-příjemný příjmově-příjmový příkladně-příkladný příležitostně-příležitostný
    přiměřeně-přiměřený přímo-přímý přímočaře-přímočarý případně-případný přirozeně-přirozený
    příslušně-příslušný přísně-přísný příspěvkově-příspěvkový příště-příští
    přitažlivě-přitažlivý příznačně-příznačný příznivě-příznivý psychicky-psychický
    psychologicky-psychologický původně-původní pyšně-pyšný racionálně-racionální
    radikálně-radikální radostně-radostný rafinovaně-rafinovaný raně-raný rapidně-rapidní
    rasově-rasový razantně-razantní rázně-rázný realisticky-realistický reálně-reálný
    recipročně-reciproční redakčně-redakční reflektivně-reflektivní regulérně-regulérní
    rekordně-rekordní rekreačně-rekreační relativně-relativní rentabilně-rentabilní
    reprezentativně-reprezentativní resortně-resortní restriktivně-restriktivní
    rezolutně-rezolutní riskantně-riskantní rizikově-rizikový rockově-rockový
    ročně-roční romanticky-romantický rovnoměrně-rovnoměrný rovnoprávně-rovnoprávný
    rozechvěle-rozechvělý rozhodně-rozhodný rozhořčeně-rozhořčený rozkošně-rozkošný
    rozpačitě-rozpačitý rozporně-rozporný rozporuplně-rozporuplný rozsáhle-rozsáhlý
    rozšafně-rozšafný roztomile-roztomilý rozumně-rozumný rozvážně-rozvážný
    rozverně-rozverný rozvroucněně-rozvroucněný ručně-ruční rusky-ruský rušno-rušný
    rutinně-rutinní různě-různý růžově-růžový rychle-rychlý rytmicky-rytmický
    řádně-řádný řádově-řádový řečnicky-řečnický řemeslně-řemeslný řetězovitě-řetězovitý
    řídce-řídký samočinně-samočinný samostatně-samostatný samoúčelně-samoúčelný
    samozřejmě-samozřejmý samozvaně-samozvaný sarkasticky-sarkastický satiricky-satirický
    sebevědomě-sebevědomý sebevražedně-sebevražedný sedminásobně-sedminásobný
    selektivně-selektivní sériově-sériový seriózně-seriózní setrvačně-setrvačný
    severně-severní severozápadně-severozápadní sevřeně-sevřený sexuálně-sexuální
    sezonně-sezónní shodně-shodný shrnutě-shrnutý silně-silný silově-silový
    skandálně-skandální skandovaně-skandovaný skepticky-skeptický skromně-skromný
    skrytě-skrytý skutečně-skutečný skvěle-skvělý skvostně-skvostný slabě-slabý
    sladce-sladký slavně-slavný slavnostně-slavnostní slepě-slepý slibně-slibný
    slovensky-slovenský slovně-slovní složitě-složitý sluchově-sluchový slušivě-slušivý
    slušně-slušný služebně-služební směle-smělý směšně-směšný smírně-smírný
    smluvně-smluvní smrtelně-smrtelný smutně-smutný smyslově-smyslový snadno-snadný
    snesitelně-snesitelný sociálně-sociální sociologicky-sociologický solidně-solidní
    sólově-sólový souběžně-souběžný souborně-souborný současně-současný soudně-soudný
    soudržně-soudržný souhlasně-souhlasný souhrnně-souhrnný soukromě-soukromý
    soustavně-soustavný soustředěně-soustředěný soutěžně-soutěžní sovětsky-sovětský
    speciálně-speciální specificky-specifický spokojeně-spokojený společensky-společenský
    společně-společný spolehlivě-spolehlivý spolu-společný spontánně-spontánní
    sponzorsky-sponzorský sporadicky-sporadický sporně-sporný sportovně-sportovní
    spořádaně-spořádaný spoře-sporý spravedlivě-spravedlivý správně-správný
    srovnatelně-srovnatelný srozumitelně-srozumitelný stabilně-stabilní stále-stálý
    standardně-standardní staročesky-staročeský statečně-statečný statisticky-statistický
    stavebně-stavební stejně-stejný stonásobně-stonásobný stoprocentně-stoprocentní
    stranicky-stranický strašlivě-strašlivý strašně-strašný strategicky-strategický
    striktně-striktní strojně-strojní stručně-stručný středně-střední střelecky-střelecký
    střídavě-střídavý střídmě-střídmý střízlivě-střízlivý studeně-studený stupňovitě-stupňovitý
    stylově-stylový subjektivně-subjektivní sugestivně-sugestivní surově-surový
    surrealisticky-surrealistický suše-suchý suverénně-suverénní svahilsky-svahilský
    svědomitě-svědomitý svérázně-svérázný sveřepě-sveřepý světle-světlý světově-světový
    svévolně-svévolný svisle-svislý svižně-svižný svobodně-svobodný svobodomyslně-svobodomyslný
    svorně-svorný svrchovaně-svrchovaný symbolicky-symbolický symfonicky-symfonický
    sympaticky-sympatický syrově-syrový systematicky-systematický šalamounsky-šalamounský
    šedě-šedý šetrně-šetrný šikmo-šikmý šikovně-šikovný široce-široký široko-široký
    škaredě-škaredý škodlivě-škodlivý šokovaně-šokovaný španělsky-španělský
    špatně-špatný špičkově-špičkový špinavě-špinavý šťastně-šťastný tabulkově-tabulkový
    tajemně-tajemný tajně-tajný takticky-taktický takzvaně-takzvaný tanečně-taneční
    taxativně-taxativní teenagersky-teenagerský technicky-technický technologicky-technologický
    telefonicky-telefonický tělesně-tělesný televizně-televizní tematicky-tematický
    temně-temný teoreticky-teoretický tepelně-tepelný těsně-těsný textově-textový
    těžce-těžký těžko-těžký tiše-tichý totálně-totální tradičně-tradiční tragicky-tragický
    transdisciplinárně-transdisciplinární trapně-trapný trefně-trefný tréninkově-tréninkový
    trestně-trestní trestuhodně-trestuhodný triumfálně-triumfální trojnásobně-trojnásobný
    trpce-trpký trpělivě-trpělivý trpně-trpný trvale-trvalý tržně-tržný tučně-tučný
    tvrdě-tvrdý tvrdošíjně-tvrdošíjný týdně-týdní typicky-typický typově-typový
    uctivě-uctivý účelně-účelný účelově-účelový účetně-účetní-1 účinně-účinný
    údajně-údajný uhrančivě-uhrančivý úhrnně-úhrnný úlevně-úlevný úlisně-úlisný
    uměle-umělý umělecky-umělecký úměrně-úměrný umně-umný úmyslně-úmyslný unaveně-unavený
    univerzálně-univerzální únosně-únosný úplně-úplný upřeně-upřený upřímně-upřímný
    úrazově-úrazový urbionalisticky-urbionalistický určitě-určitý urychleně-urychlený
    úředně-úřední úsečně-úsečný usilovně-usilovný uspěchaně-uspěchaný úspěšně-úspěšný
    uspokojivě-uspokojivý ustavičně-ustavičný ústavně-ústavní ústně-ústní ústrojně-ústrojný
    utěšeně-utěšený uvěřitelně-uvěřitelný uvnitř-vnitřní úzce-úzký územně-územní
    územněsprávně-územněsprávní úzkostlivě-úzkostlivý úzkostně-úzkostný valně-valný
    vančurovsky-vančurovský varovně-varovný vášnivě-vášnivý vážně-vážný věcně-věcný
    věčně-věčný vědecky-vědecký vědomě-vědomý vehementně-vehementní věkově-věkový
    velkoryse-velkorysý verbálně-verbální věrně-věrný věrohodně-věrohodný vertikálně-vertikální
    veřejně-veřejný veřejnoprávně-veřejnoprávní vesele-veselý větrno-větrný
    vhod-vhodný vhodně-vhodný víceúčelově-víceúčelový viditelně-viditelný virtuózně-virtuózní
    vítězně-vítězný vkusně-vkusný vlastnoručně-vlastnoruční vlažně-vlažný vnějškově-vnějškový
    vnímavě-vnímavý vnitropoliticky-vnitropolitický vnitřně-vnitřní vodivě-vodivý
    vodorovně-vodorovný vojensky-vojenský vokálně-vokální volně-volný vratce-vratký
    vrcholně-vrcholný vrcholově-vrcholový vrozeně-vrozený vřele-vřelý vstřícně-vstřícný
    všelijak-všelijaký všeobecně-všeobecný všestranně-všestranný vtipně-vtipný
    vtíravě-vtíravý vulgárně-vulgární výběrově-výběrový výborně-výborný vybraně-vybraný
    výdajově-výdajový vydatně-vydatný výdělečně-výdělečný výhledově-výhledový
    výhodně-výhodný výhradně-výhradní vyhýbavě-vyhýbavý výjimečně-výjimečný
    vyloženě-vyložený výlučně-výlučný výmluvně-výmluvný vypjatě-vypjatý výrazně-výrazný
    výrazově-výrazový vyrovnaně-vyrovnaný výřečně-výřečný výsledně-výsledný
    vysloveně-vyslovený výslovně-výslovný vysoce-vysoký vysoko-vysoký vysokoškolsky-vysokoškolský
    výstižně-výstižný výtečně-výtečný vytrvale-vytrvalý vytrženě-vytržený výtvarně-výtvarný
    významně-významný významově-významový vyzrále-vyzrálý vzácně-vzácný vzájemně-vzájemný
    vzdáleně-vzdálený vzhledově-vzhledový vzorně-vzorný vzrušeně-vzrušený záhadně-záhadný
    zahraničně-zahraniční zajímavě-zajímavý zákonitě-zákonitý zákonně-zákonný
    zakřiknutě-zakřiknutý zálibně-zálibný zálohově-zálohový záměrně-záměrný
    zamračeně-zamračený zanedbatelně-zanedbatelný zaníceně-zanícený zaobaleně-zaobalený
    západně-západní záporně-záporný zarputile-zarputilý zaručeně-zaručený zarytě-zarytý
    zařaditelně-zařaditelný zásadně-zásadní zaslouženě-zasloužený zastřeně-zastřený
    zasvěceně-zasvěcený zatraceně-zatracený zatvrzele-zatvrzelý závazně-závazný
    závažně-závažný záviděníhodně-záviděníhodný závistivě-závistivý závratně-závratný
    zázračně-zázračný zběsile-zběsilý zbrkle-zbrklý zbytečně-zbytečný zdánlivě-zdánlivý
    zdařile-zdařilý zděšeně-zděšený zdlouhavě-zdlouhavý zdravě-zdravý zdravotně-zdravotní
    zdrženlivě-zdrženlivý zdvořile-zdvořilý zelenobíle-zelenobílý zevrubně-zevrubný
    zištně-zištný zjednodušeně-zjednodušený zjevně-zjevný zkoumavě-zkoumavý
    zkratkovitě-zkratkovitý zlatavě-zlatavý zle-zlý zlobně-zlobný zlomyslně-zlomyslný
    zlověstně-zlověstný značně-značný znamenitě-znamenitý znatelně-znatelný
    znechuceně-znechucený zodpovědně-zodpovědný zoufale-zoufalý zpětně-zpětný
    zpropadeně-zpropadený zprostředkovaně-zprostředkovaný zpupně-zpupný zrakově-zrakový
    zrcadlově-zrcadlový zrychleně-zrychlený zřejmě-zřejmý zřetelně-zřetelný
    ztepile-ztepilý zvláštně-zvláštní zvukově-zvukový žalostně-žalostný žánrově-žánrový
    živě-živý životně-životní žíznivě-žíznivý);
    
    
sub get_adjective {
    my $adv = shift;
    return $adv2adj{$adv};
}


1;

__END__

=pod

=head1 NAME

Treex::Tool::Lexicon::CS::Adverbia

=cut

# Copyright 2011 David Marecek
