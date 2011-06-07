package Treex::Tools::Lexicon::CS::Adverbia;

use strict;
use warnings;
use utf8;

my %pronomadv;
map {$pronomadv{$_} = 1} qw(
    dokdy dokud jak jakkoliv jaksi jakž kam kamkoliv kampak kamsi kde kdekoliv
    kdepak kdesi kdeže kdy kdykoli kdysi kudy leckde leckdy málokde málokdy
    navždy nějak někam někde někdy nijak nikam nikde nikdy odevšad odkdy odkud
    odněkud odnikud odsud onak onde onehdá pak poté potom potud proč proto sem
    tady taktéž takž tam tamhle tamtéž teď tudy tuhle tytam všudy vždy zde);

my %nongradableadv;
map{ $nongradableadv{$_} = 1} qw(
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
map {$notnegableadv{$_} = 1 } qw(
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

1;

__END__

=pod

=head1 NAME

Treex::Tools::Lexicon::CS::Adverbia

=cut

# Copyright 2011 David Marecek
