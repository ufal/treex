package Treex::Tool::Lexicon::CS::Aspect;

use strict;
use warnings;
use utf8;
use Treex::Tool::Lexicon::CS;

my @verbs = qw(
    číhat-I čalounit-I čarovat-I číslovat-I časovat-I číst-I častit-I častovat-I
    čítávat-I čítat-I abdikovat-B absentovat-I absolutizovat-I absolvovat-B
    absorbovat-B abstrahovat-B adaptovat-B adoptovat-P adresovat-B čekávat-I
    čekat-I čelit-I čepovat-I čerpat-I česat-I agitovat-I čišet-I činívat-I
    činit-I čistit-I akcelerovat-I akcentovat-I akceptovat-B aklimatizovat-B
    akreditovat-B aktivizovat-B aktivovat-B aktualizovat-B akumulovat-I alarmovat-I
    členit-I alternovat-I amputovat-B analyzovat-I čnít-I čnět-I anektovat-B
    angažovat-B animovat-I anoncovat-B antropomorfizovat-I anulovat-B čouhat-I
    čpět-I apelovat-I aplaudovat-I aplikovat-B aranžovat-B argumentovat-I archivovat-I
    artikulovat-I účastnit-I účinkovat-I účtovat-I asimilovat-B asistovat-I
    úřadovat-I asociovat-I aspirovat-I úročit-I ústit-I útočit-I úvěrovat-I
    atakovat-I atomizovat-B čuchnout-P avizovat-B bádat-I básnit-I bát-I bědovat-I
    bagatelizovat-I běhávat-I běhat-I balancovat-I balit-I běžet-I banalizovat-I
    bankrotovat-I barvit-I bít-I být-I batolit-I bývávat-I bývat-I bavit-I bazírovat-I
    bdít-I bečet-I belhat-I besedovat-I bičovat-I bilancovat-I bivakovat-I blábolit-I
    blahopřát-I blížit-I blamovat-I blýskat-I blýsknout-P blednout-I břinknout-P
    blokovat-B bloudit-I blufovat-I bodnout-P bodovat-I bohatnout-I bojkotovat-I
    bojovat-I bolet-I bořit-I bombardovat-I bortit-I bouchnout-P bouřit-I bourat-I
    boxovat-I bránit-I brát-I brávat-I brázdit-I bratřit-I brblat-I brečet-I
    brnknout-P brodit-I brojit-I brousit-I bručívat-I bručet-I brumlat-I bruslit-I
    brzdit-I bubnovat-I budit-I budovat-I bujet-I bušit-I burácet-I burcovat-I
    bydlívat-I bydlet-I bzučet-I cílit-I cítívat-I cítit-I cedit-I cejchovat-I
    ceknout-P cementovat-I cenit-I centrovat-I cestovat-I citovat-B civět-I
    cizelovat-I clít-I couvat-I couvnout-P cpát-I crčet-I ctít-I cukat-I cuknout-P
    cválat-I cvičit-I cvrnkat-I dát-P dávat-I dávit-I dabovat-I dědit-I dýchat-I
    dýchnout-P děkovat-I dělávat-I dělat-I dařívat-I dařit-I dělit-I darovat-B
    děsit-I démonizovat-I dít-I datovat-B dívat-I dbát-I debatovat-I debutovat-B
    decentralizovat-B defilovat-I definovat-B deformovat-I degradovat-B dechnout-P
    deklarovat-B dešifrovat-B delegovat-B dementovat-B demokratizovat-B demolovat-B
    demonopolizovat-B demonstrovat-B demontovat-B deponovat-B deportovat-B deprimovat-I
    deptat-I destabilizovat-B detekovat-I determinovat-B devalvovat-B devastovat-B
    dezaktivovat-B dezinfikovat-B dezorganizovat-B diagnostikovat-I diferencovat-B
    diktovat-I dirigovat-I diskontovat-I diskreditovat-B diskriminovat-I diskutovat-I
    diskvalifikovat-B dislokovat-B disponovat-I distancovat-B distribuovat-B
    divergovat-I diverzifikovat-I divit-I dláždit-I dřímat-I dlít-I dřít-I dloubat-I
    dlužit-I důvěřovat-I dočíst-P dočítat-I dočkat-P dobíhat-I doběhnout-P dobírat-I
    dobýt-P dobývat-I dobrat-P dobudovat-P docílit-P doceňovat-I docenit-P docilovat-I
    dodávat-I dodělávat-I dodanit-P dodat-P dodržet-P dodržovat-I dofinišovat-P
    dohánět-I dohadovat-I dohasínat-I dohasnout-P dohlížet-I dohlédnout-P dohledávat-I
    dohledat-P dohmátnout-P dohnat-P dohodnout-P dohonit-P dohotovit-P dohovořit-P
    dohrát-P dohrávat-I docházet-I dochovat-P dochytat-P dojídat-I dojíždět-I
    dojímat-I dojít-P dojednat-P dojet-P dojit-I dojmout-P dokázat-P dokazovat-I
    dokládat-I dokladovat-I doklepnout-P doklopýtat-P dokončit-P dokončovat-I
    dokonat-P dokoupit-P dokralovat-P dokreslit-P dokreslovat-I dokumentovat-B
    dolaďovat-I doříci-P doladit-P došlápnout-P doléhat-I dolétnout-P dolehnout-P
    dořešit-P doleptat-P doletět-P doložit-P dolomit-P dožadovat-I dožít-P dožívat-I
    domáhat-I domýšlet-I domalovat-P domazat-P dominovat-I domlouvat-I domluvit-P
    domnívat-I domoci-P domyslet-P domyslit-P donášet-I donést-P donosit-P donutit-P
    dopátrat-P dopadat-I dopadnout-P dopéci-P dopisovat-I doplácet-I dopřát-P
    dopřávat-I doplatit-P doplavat-P doplazit-P doplňovat-I doplnit-P dopočítávat-I
    dopočítat-P dopomáhat-I dopomoci-P doporučit-P doporučovat-I dopouštět-I
    dopovat-I dopracovávat-I dopracovat-P dopravit-P dopravovat-I doprodat-P
    doprovázet-I doprovodit-P dopsat-P dopustit-P doputovat-P dorážet-I dorazit-P
    dorůst-P dorůstat-I dorovnat-P dorozumět-P dorozumívat-I doručit-P doručovat-I
    dosáhnout-P dosadit-P dosahovat-I dosazovat-I dosednout-P doslechnout-P
    dosloužit-P dosluhovat-I dospět-P dospívat-I dostačovat-I dostát-P dostávat-I
    dostat-P dostavět-P dostavit-P dostavovat-I dostihnout-P dostihovat-I dostoupit-P
    dostrkat-P dosvědčit-P dosvědčovat-I dotáhnout-P dotázat-P dotýkat-I dotírat-I
    dotazovat-I dotisknout-P dotknout-P dotovat-I dotrpět-P dotvářet-I dotvořit-P
    dotvrzovat-I doufat-I doutnat-I dovádět-I dovážet-I dovážit-P dovídat-I
    dovědět-P dovařit-P dovažovat-I dovést-I dovézt-P dovodit-P dovolávat-I
    dovolat-P dovolit-P dovolovat-I dovozovat-I dovršit-P doznávat-I doznat-P
    doznít-P doznívat-I dozrát-P dozrávat-I dozvídat-I dozvědět-P dozvonit-P
    dráždit-I drát-I draftovat-I dražit-I dramatizovat-I drhnout-I držet-I drobit-I
    drolit-I drožkařit-I drtit-I družit-I dušovat-I dunět-I dusat-I dusit-I
    dvojit-I elektrifikovat-B eliminovat-B emanovat-I emigrovat-B emitovat-I
    erodovat-I eskalovat-I eskontovat-I eskortovat-B etablovat-I evakuovat-B
    evidovat-I evokovat-B excelovat-I existovat-I expandovat-I expedovat-B experimentovat-I
    explodovat-B exportovat-B extrahovat-B fackovat-I fakturovat-I falšovat-I
    fandit-I fantazírovat-I farmařit-I fascinovat-I fasovat-I fúzovat-I fauloval-I
    favorizovat-I faxovat-B fičet-I figurovat-I filozofovat-I financovat-I finišovat-I
    fixlovat-I fixovat-B flákat-I flámovat-I flirtovat-I formalizovat-I formovat-I
    formulovat-B fotografovat-I foukat-I frčet-I frustrovat-I fungovat-I garantovat-B
    generovat-I glajchšaltovat-I globalizovat-I glosovat-B gratulovat-I hádat-I
    hájit-I hýčkat-I házet-I hýbat-I hýbnout-P halit-I hýřit-I handicapovat-B
    hanobit-I harmonizovat-B harmonovat-I hasit-I hasnout-I havarovat-I hazardovat-I
    hecovat-I hekat-I hemžit-I hlásat-I hlásit-I hřát-I hlídat-I hladit-I hlídkovat-I
    hladovět-I hlaholit-I hřímat-I hlasovat-I hlavičkovat-I hledávat-I hledat-I
    hledět-I hřešit-I hřmět-I hloubit-I hltat-I hnát-I hněvat-I hnisat-I hnout-P
    hodit-I hodlat-I hodnotit-I hojit-I holdovat-I holedbat-I hořet-I holit-I
    homologovat-I honit-I honorovat-B honosit-I horlit-I hospitalizovat-B hospodařit-I
    hostit-I hostovat-I houfovat-I houkat-I houpat-I houstnout-I hovět-I hovořívat-I
    hovořit-I hrát-I hrávat-I hrabat-I hradívat-I hradit-I hraničit-I hrknout-P
    hrnout-I hromadit-I hroutit-I hrozívat-I hrozit-I hučet-I hubnout-I hulit-I
    hvízdat-I hvízdnout-P hynout-I hypertrofovat-B hyzdit-I chápat-I chátrat-I
    chýlit-I charakterizovat-B chlácholit-I chladit-I chladnout-I chlubit-I
    chodívat-I chodit-I chopit-P chovat-I chránit-I christianizovat-I chrlit-I
    chtít-I chudnout-I chutnat-I chválit-I chvástat-I chvět-I chybět-I chybívat-I
    chybit-I chybovat-I chystat-I chytat-I chytit-P chytnout-P idealizovat-B
    identifikovat-B ideologizovat-I ignorovat-I ilustrovat-B imitovat-I implantovat-I
    implikovat-I imponovat-I importovat-B improvizovat-I imputovat-B imunizovat-B
    indikovat-B indisponovat-I indukovat-B infiltrovat-B informovat-B iniciovat-B
    inkasovat-B inklinovat-I inovovat-B inscenovat-B inspirovat-B instalovat-B
    institucionalizovat-I instruovat-B integrovat-B interferovat-I internacionalizovat-B
    internovat-B interpelovat-B interpretovat-B intervenovat-B intrikovat-I
    inventarizovat-B investovat-I inzerovat-I iritovat-I izolovat-I jásat-I
    jídat-I jímat-I jíst-I jít-I jednávat-I jednat-I ježit-I jet-I jevit-I jezdívat-I
    jezdit-I jiskřit-I jistit-I jmenovat-I jmout-P joggovat-I kácet-I kárat-I
    kát-I kázat-I kýchnout-P kašlat-I kódovat-B kalit-I kalkulovat-I kótovat-I
    kamarádit-I kandidovat-I kapat-I kapitulovat-B katapultovat-B kategorizovat-B
    kývat-I kývnout-P kazit-I kecat-I klíčit-I klást-I klátit-I křížit-I klamat-I
    klapat-I klasifikovat-B kleknout-P klenout-I křepčit-I klepat-I klepnout-P
    klesat-I klesnout-P křičívat-I křičet-I kličkovat-I klikatit-I křiknout-P
    křižovat-I křivdit-I klonit-I klopýtat-I klouzat-I klubat-I kmitat-I kočkovat-I
    kočovat-I kodifikovat-B koexistovat-I kochat-I kojit-I koketovat-I kolíbat-I
    kolaborovat-I kolabovat-I kolísat-I kolébat-I kořenit-I kolidovat-I kolonizovat-B
    kolovat-I kombinovat-I komentovat-B komolit-I komorovat-I kompenzovat-B
    kompilovat-I komplikovat-I komponovat-I komunikovat-I končívat-I končit-I
    konat-I koncentrovat-B koncertovat-I koncipovat-B kondolovat-B konejšit-I
    konferovat-I konfiskovat-I konfrontovat-B konkretizovat-B konkurovat-I konsolidovat-B
    konspirovat-I konstatovat-B konstituovat-B konstruovat-I kontaktovat-B kontaminovat-B
    kontrahovat-B kontrastovat-I kontrolovat-I kontrovat-I kontumovat-I konvergovat-I
    konvertovat-B konverzovat-I konzervovat-B konzultovat-I konzumovat-I kooperovat-I
    koordinovat-B kopírovat-I kopat-I kopnout-P korespondovat-I korigovat-B
    korodovat-I korumpovat-I korunovat-I kotvit-I koukat-I kouknout-P kouřit-I
    koupat-I koupit-P kousat-I kouskovat-I kousnout-P kouzlit-I kovat-I kráčet-I
    krájet-I krášlit-I krást-I krátit-I krčit-I kralovat-I krýt-I kreslit-I
    kritizovat-I krmit-I kroužit-I kroutit-I kručet-I krystalizovat-I kulhat-I
    kulminovat-I kultivovat-I kumulovat-I kupovat-I kutálet-I kvalifikovat-B
    kvantifikovat-I kvést-I kvitovat-B kydat-I kypět-I řádit-I ládovat-I líčit-I
    lákat-I šílet-I šířit-I lámat-I šít-I líbat-I líbit-I laborovat-I říci-P
    ladit-I řadit-I řídit-I řídnout-I šelestit-I šeptávat-I šeptat-I šeptnout-P
    šermovat-I šetřit-I líhnout-I šidit-I šifrovat-B šikanovat-I šilhat-I říkávat-I
    říkat-I šklebit-I škobrtnout-P škodit-I školit-I škrábat-I škrábnout-P škrtat-I
    škrtit-I škrtnout-P škubnout-P škytnout-P šlápnout-P šlapat-I šlehat-I šťourat-I
    šňupat-I šůrovat-I lamentovat-I šněrovat-I šokovat-B šoupnout-P šoustnout-P
    lapat-I špehovat-I špinit-I lapit-P špitat-I špitnout-P šplhat-I šplhnout-P
    šponovat-I šroubovat-I léčit-I léhat-I létat-I lézt-I lít-I štěkat-I štípat-I
    štěpit-I lítat-I štítit-I řítit-I štvát-I šukat-I šuškat-I šulit-I šumět-I
    šustit-I lízat-I říznout-P ředit-I legalizovat-B legitimizovat-I legitimovat-B
    lehat-I lehnout-P lekat-I leknout-P řeknout-P řešívat-I řešit-I ležet-I
    lemovat-I lenit-I lepit-I lepšit-I leptat-I letět-I řezat-I lhát-I liberalizovat-B
    libovat-I licitovat-I lichotit-I likvidovat-B lišívat-I lišit-I limitovat-B
    řinčet-I linout-I řinout-I listovat-I litovat-I lnout-I lobbovat-I lokalizovat-B
    lomcovat-I lomit-I losovat-I loučit-I loupit-I loutkařit-I lovit-I lpět-I
    lustrovat-B luxovat-I řvát-I lyžovat-I lze-I žádávat-I žádat-I žárlit-I
    žadonit-I žalovat-I žasnout-I žít-I žebrat-I žehnat-I žehrávat-I žehrat-I
    ženit-I žertovat-I žhavit-I živit-I živořit-I životnět-I žonglovat-I žrát-I
    žvýkat-I máčet-I máchat-I mačkat-I mást-I mávat-I mávnout-P magnetizovat-I
    míhat-I míchat-I míjet-I makat-I měřívat-I mařit-I mýlit-I mířit-I měřit-I
    malovat-I mínívat-I měnívat-I manifestovat-B manipulovat-I mínit-I měnit-I
    mapovat-I masakrovat-B mísit-I maskovat-B mít-I mýt-I materializovat-I maturovat-I
    mívat-I maximalizovat-B mazat-I mazlit-I meditovat-I metabolizovat-I metat-I
    mhouřit-I migrovat-I mihnout-P milovat-I minimalizovat-B minout-P mizet-I
    mlátit-I mlčívat-I mlčet-I mlít-I mluvívat-I mluvit-I mžít-I mžourat-I množit-I
    mnout-I mobilizovat-I moci-I modelovat-I modernizovat-B moderovat-I modifikovat-B
    modlívat-I modlit-I modulovat-I mokvat-I mořit-I monitorovat-I monopolizovat-B
    montovat-I monumentalizovat-I motat-I motivovat-B mračit-I mrknout-P mrštit-P
    mrskat-I mrzet-I mrznout-I mstít-I mučit-I mumlat-I muset-I musit-I myslet-I
    myslit-I načasovat-P načít-P načechrat-P načerpat-P naakumulovat-P náležet-I
    naaranžovat-P nárokovat-I načrtávat-I načrtnout-P naúčtovat-P následovat-I
    násobit-I nabádat-I nabídnout-P nabíhat-I naběhat-B naběhnout-P nabalit-P
    nabalovat-I nabírat-I nabít-P nabýt-P nabývat-I nabízet-I nablít-P nabourávat-I
    nabourat-P nabrat-P nacvičovat-I nadát-P nadávat-I nadýchat-P nadělat-B
    nadělit-P nadat-P nadechnout-P nadejít-P nadhodit-P nadhodnotit-P nadcházet-I
    nadchnout-P nadiktovat-P nadřadit-P nadřít-B nadlehčit-P nadsazovat-I nadužít-P
    nadzvednout-P nafackovat-P nafilmovat-P nafouknout-P nafukovat-I nahánět-I
    naházet-P nahazovat-I nahlásit-P nahlašovat-I nahlížet-I nahlédnout-P nahřívat-I
    nahlodat-P nahmátnout-P nahmatat-P nahnat-P nahodit-P nahrát-B nahrávat-I
    nahrabat-P nahradit-P nahrazovat-I nahromadit-P nacházet-I nachýlit-P nachylovat-I
    nachystat-P nachytat-P nainstalovat-P najíždět-I najímat-I najíst-P najít-P
    najet-B najmout-P nakazit-P nakládat-I naklánět-I naklást-P naklonit-P nakomandovat-P
    nakoupit-P nakousnout-P nakrájet-P nakrást-P nakreslit-P nakukovat-I nakupit-P
    nakupovat-I nakutat-P nalíčit-I nalákat-P naladit-P nařídit-P našeptávat-I
    naříkat-I našlápnout-P naléhat-I nalévat-I nalézat-I nalézt-P nalít-P nalítnout-P
    naštvat-P naříznout-P nalepit-P nalepovat-I naleptávat-I naletět-P nařezat-P
    naleznout-P nalhávat-I nalistovat-P nařizovat-I nařknout-P naťukat-P nalodit-P
    naložit-P nalomit-P naloupit-P nalovit-P nažrat-P namáhat-I namíchávat-I
    namíchat-P namířit-P naměřit-P namalovat-P namarkovat-P namítat-I namítnout-P
    namazat-P namluvit-B namnožit-P namočit-P namontovat-P nanášet-I nanést-P
    nandat-P naoktrojovat-P napáchat-B napájet-I napálit-P napást-P napadat-I
    napadnout-P napíchat-P napařit-P napěstovat-P napít-P naplánovat-P napřít-P
    naplňovat-I naplnit-P napnout-P napočíst-P napočítat-P napodobit-P napodobovat-I
    napojit-P napojovat-I napomáhat-I napomínat-I napomenout-P napomoci-P napovídat-I
    napovědět-P napravit-P napravovat-I napršet-P naprogramovat-P napsat-P napumpovat-P
    napustit-P narážet-I narýžovat-P narazit-P narůst-P narůstat-I narodit-P
    naroubovat-P narušit-P narušovat-I nasát-P nasázet-P nasadit-P nasít-P nasazovat-I
    nasbírat-P nasedat-I nasednout-P naservírovat-P nashromáždit-P nasimulovat-P
    naskakovat-I naskýtat-I naskicovat-P naskočit-P naskytnout-P naslouchat-I
    nasměrovat-P nasmlouvat-P nastávat-I nastěhovat-P nastínit-P nastartovat-P
    nastat-P nastavit-P nastavovat-I nastříkat-P nastřílet-P nastřelit-P nastolit-P
    nastolovat-I nastoupit-P nastrčit-P nastražit-P nastudovat-P nastupovat-I
    nastydnout-P nasvědčovat-I nasypat-P nasytit-P nést-I natáčet-I natáhnout-P
    natahovat-I natírat-I natéci-P natřít-P natočit-P natrénovat-P natrhnout-P
    naturalizovat-B naučit-P navádět-I navázat-P navýšit-P navalit-P navazovat-I
    navečeřet-P naverbovat-P navléknout-P navštívit-P navštěvovat-I navodit-P
    navozovat-I navrátit-P navracet-I navrhnout-P navrhovat-I navyknout-P navyšovat-I
    nazírat-I nazývat-I naznačit-P naznačovat-I nazpívat-I nazrát-P nazvat-P
    nedbat-I negovat-I nechávat-I nechat-P nenávidět-I neokázala-P nervovat-I
    nesnášet-I neutralizovat-B nezbývat-I ničit-I nocovat-I nominovat-B normalizovat-B
    nosívat-I nosit-I novelizovat-B nudit-I nutívat-I nutit-I očíslovat-P očekávat-I
    očernit-P očistit-P očkovat-I obávat-I občerstvovat-I obíhat-I obalamutit-P
    obírat-I oběsit-P obětovat-P obývat-I obdařit-P obdařovat-I obdarovat-P
    obdivovat-I obdržet-P obehrát-P obehrávat-I obejít-P obejit-P obejmout-P
    obeplout-P obesílat-I obestírat-I obestřít-P obezdívat-I obeznámit-P obhájit-P
    obhánět-I obhajovat-I obhlédnout-P obhospodařovat-I obcházet-I obchodovat-I
    objíždět-I objímat-I objasňovat-I objasnit-P objednávat-I objednat-P objektivizovat-I
    objet-P objevit-P objevovat-I obklíčit-P obklopit-P obklopovat-I obšancovat-P
    obšívat-I oblíbit-P obšlápnout-P obšťastňovat-I oblažit-P oblažovat-I obléci-P
    obléhat-I oblékat-I obléknout-P obletět-P obložit-P obžalovat-P obměňovat-I
    obmyslet-P obnášet-I obnažovat-I obnovit-P obnovovat-I obohacovat-I obohatit-P
    obořit-P obouvat-I obrážet-I obrátit-I obracet-I obrat-P obrůst-P obrůstat-I
    obrodit-P obrousit-P obrušovat-I obsáhnout-P obsadit-P obsahovat-I obsazovat-I
    obsloužit-P obsluhovat-I obstát-P obstarávat-I obstarat-P obstoupit-P obtížit-P
    obtěžkat-P obtěžovat-I obveselit-P obviňovat-I obvinit-P obydlet-P ocejchovat-P
    oceňovat-I ocenit-P ocitat-I ocitnout-P ocitovat-P ocnout-P octnout-P odčarovat-P
    odčerpávat-I odčerpat-P odčinit-P odírat-I odít-P odbíhat-I odběhnout-P
    odbarvovat-I odbýt-P odbývat-I odbavovat-I odbřemenit-P odblokovat-P odbočovat-I
    odbourávat-I odbourat-P odbrzdit-P odcentrovat-P odcestovat-P odcizit-P
    odcizovat-I oddálit-P oddávat-I oddělat-P oddělit-P oddalovat-I oddělovat-I
    oddat-P oddechnout-P oddychnout-P oddychovat-I odečíst-P odečítat-I odebírat-I
    odebrat-P odehnat-P odehrát-P odehrávat-I odejít-P odejet-P odejmout-P odemknout-P
    odepisovat-I odepřít-P odepsat-P odesílat-I odeslat-P odevzdávat-I odevzdat-P
    odezírat-I odeznít-P odeznívat-I odhánět-I odhadnout-P odhadovat-I odhalit-P
    odhalovat-I odhlásit-P odhlasovat-P odhlédnout-P odhodit-P odhodlávat-I
    odhodlat-P odhrabat-P odcházet-I odchýlit-P odchodit-P odchovat-P odchylovat-I
    odchytit-P odjíždět-I odjet-P odjistit-P odkázat-P odkapávat-I odkazovat-I
    odkládat-I odklánět-I odklízet-I odklidit-P odklonit-P odkopávat-I odkoupit-P
    odkráčet-P odkrýt-P odkrývat-I odkupovat-I odlákat-P odříci-P odříkávat-I
    odříkat-I odškodňovat-I odškodnit-P odlétat-I odřít-P odštěpit-P odříznout-P
    odlehčit-P odřeknout-P odlepit-P odletět-P odřezávat-I odlišit-P odlišovat-I
    odložit-P odlomit-P odloučit-P odlučovat-I odlupovat-I odůvodňovat-I odůvodnit-P
    odmávat-P odměňovat-I odměřovat-I odměnit-P odmítat-I odmítnout-P odmaturovat-P
    odmlčet-P odmontovat-P odmrštit-P odmyslit-P odnášet-I odnímat-I odnést-P
    odnaučit-P odnaučovat-I odolávat-I odolat-P odoperovat-P odpálit-P odpadat-I
    odpadnout-P odpařit-P odpařovat-I odpírat-I odpírat;-I odpískat-P odplížit-P
    odplavit-P odpřisáhnout-P odplout-P odplouvat-I odpočíst-P odpočívat-I odpočinout-P
    odpochodovat-P odpolitizovat-P odpomoci-P odporovat-I odpouštět-I odpoutávat-I
    odpoutat-P odpovídat-I odpovědět-P odpracovat-P odpreparovat-P odprodávat-I
    odprodat-P odpustit-P odpuzovat-I odpykávat-I odpykat-P odrážet-I odradit-P
    odrazit-P odrazovat-I odreagovat-P odrůst-P odročit-P odsát-P odsávat-I
    odsedět-P odsednout-P odseknout-P odskákat-P odskakovat-I odskočit-P odsloužit-P
    odsoudit-P odsouhlasit-P odsouvat-I odstátnit-P odstěhovat-P odstartovat-P
    odstavit-P odstavovat-I odstřelit-P odstřelovat-I odstoupit-P odstrčit-P
    odstrašovat-I odstraňovat-I odstranit-P odstupňovat-P odstupovat-I odsunout-P
    odsuzovat-I odtajnit-P odtékat-I odtlačovat-I odtrhnout-P odtrhovat-I odtroubit-P
    odvádět-I odvážet-I odvážit-P odvát-P odvíjet-I odvalit-P odvažovat-I odvanout-P
    odvést-P odvézt-P odvětit-P odvětvovat-I odvděčit-P odvděčovat-I odvelet-P
    odvinit-P odvinout-P odvléci-P odvodit-P odvolávat-I odvolat-P odvozit-P
    odvozovat-I odvrátit-P odvracet-I odvrhnout-P odvrtat-P odvyknout-P odvysílat-P
    odzbrojit-P odzbrojovat-I ohánět-I ohýbat-I ohlásit-P ohřát-P ohlídat-P
    ohlašovat-I ohlížet-I ohlédnout-P ohřívat-I ohledat-P ohluchnout-P ohodnocovat-I
    ohodnotit-P ohořet-P oholit-P ohrát-P ohrávat-I ohradit-P ohrazovat-I ohrožovat-I
    ohromit-P ohrozit-P ochabnout-P ochladit-P ochladnout-P ochlazovat-I ochránit-P
    ochraňovat-I ochromit-P ochromovat-I ochudit-P ochutnat-P ochuzovat-I okázat-P
    okřídlit-P oklamat-P oklešťovat-I okleštit-P okořenit-P okomentovat-P okopávat-P
    okopírovat-P okoukat-P okouknout-P okouzlit-P okouzlovat-I okrádat-I okrást-P
    oktrojovat-B okupovat-I okusit-P okusovat-I ošetřit-P ošetřovat-I ošidit-P
    ošlapat-P ošoustat-P oťukat-P oloupat-P oloupit-P ožít-P ožívat-I ožebračovat-I
    oželet-P oženit-P oživit-P oživovat-I omalovat-P omývat-I omdlít-P omezit-P
    omezovat-I omilostnit-P omládnout-P omlátit-P omladit-P omlouvat-I omluvit-P
    omráčit-P onemocnět-P opáčit-P opájet-I opálit-P opásat-P opadávat-I opadnout-P
    opíjet-I opakovat-I opařit-P opalovat-I opírat-I opít-P opatřit-P opatřovat-I
    opětovat-I opatrovat-I operovat-I opevňovat-I opisovat-I oplakávat-I opřít-P
    oplatit-P oplývat-I oplodnit-P oplotit-P opodstatňovat-I opojit-P opožďovat-I
    opomíjet-I opomenout-P oponovat-I opouštět-I opozdit-P oprášit-P oprávnit-P
    oprat-P opravit-P opravňovat-I opravovat-I oprostit-P optat-P optimalizovat-B
    opustit-P orat-I orazit-P ordinovat-I organizovat-B orientovat-B orosit-P
    osadit-P osídlit-P osahávat-I osahat-P osamostatnit-P osazovat-I oscilovat-I
    osidlovat-I osiřet-P oslabit-P oslabovat-I osladit-P oslavit-P oslavovat-I
    oslazovat-I oslepit-P oslnit-P oslovit-P oslovovat-I oslyšet-P osmělit-P
    osočit-P osočovat-I osobovat-I osolit-P ospravedlňovat-I ospravedlnit-P
    ostýchat-I ostříhat-P ostřelovat-I ostřit-I ostrouhat-P osušit-P osvědčit-P
    osvědčovat-I osvěžit-P osvítit-P osvětlit-P osvětlovat-I osvobodit-P osvobozovat-I
    osvojit-P osvojovat-I otáčet-I otálet-I otázat-P otěhotnět-P otéci-P otékat-I
    oteplit-P oteplovat-I otestovat-P otevírat-I otevřít-P otipovat-P otisknout-P
    otiskovat-I otřásat-I otřást-P otřít-P otočit-P otrávit-P otravovat-I otrkat-P
    otrnout-P otužovat-I otupět-P otupovat-I otvírat-I ověřit-P ověřovat-I ověsit-P
    ovdovět-P ovládat-I ovládnout-P ovlivňovat-I ovlivnit-P oxidovat-B ozářit-P
    ozývat-I ozbrojit-P ozdobit-P ozdravit-P ozdravovat-I ozřejmit-P označit-P
    oznámit-P označovat-I oznamovat-I ozvat-P ozvláštnit-P páchat-I páchnout-I
    pálit-I pást-I pátrat-I pacifikovat-B padělat-P padat-I pídit-I padnout-P
    píchat-I píchnout-P pachtovat-I pašovat-I pózovat-I pamatovat-I pěnit-I
    panovat-I parafovat-B parafrázovat-B paralyzovat-B parazitovat-I parkovat-I
    parodovat-I participovat-I pískat-I písknout-P pasovat-B pěstovat-I péci-I
    pít-I pět-I patentovat-B patřívat-I patřit-I pečetit-I pečovat-I penalizovat-B
    pentlit-I penzionovat-B perzekuovat-I perzekvovat-I peskovat-I pilotovat-I
    pinkat-I pinknout-P piplat-I pitvat-I plácat-I plácnout-P příčit-I plánovat-I
    přát-I přátelit-I plakat-I plašit-I plížit-I planout-I přísahat-I příslušet-I
    příspívat-I příst-I plédovat-I plést-I přít-I platívat-I platit-I plýtvat-I
    plavat-I plavit-I plazit-I přečíslovat-P přečíst-P přečerpat-P přečkat-P
    přebíhat-I přeběhnout-P přebírat-I přebít-P přebývat-I přebolet-P přebrat-P
    přebudovat-P přeceňovat-I přecenit-P předčítat-I předávat-I předávkovat-P
    předčit-B předělávat-I předělat-P předat-P předbíhat-I předběhnout-P předehrávat-I
    předejít-P předepisovat-I předepsat-P předestřít-P předhánět-I předhazovat-I
    předcházet-I předimenzovat-P předjímat-I předkládat-I předřadit-P předříkávat-I
    předložit-P předlužit-P přednášet-I přednést-P předpisovat-I předplatit-P
    předpokládat-I předpovídat-I předpovědět-P předražit-P předražovat-I předsedat-I
    předsevzít-P předstírat-I představit-P představovat-I předstihnout-P předstoupit-P
    předstupovat-I předtisknout-P předurčit-P předurčovat-I předvádět-I předvídat-I
    předvést-P předvolávat-I předvolat-P předznamenávat-I předznamenat-P přefilmovat-P
    přehánět-I přehazovat-I přehřát-P přehlížet-I přehlasovat-P přehlédnout-P
    přehlavičkovat-P přehlcovat-I přehltit-P přehnat-P přehodit-P přehodnocovat-I
    přehodnotit-P přehoupnout-P přehrát-P přehrávat-I přehradit-P přecházet-I
    přechodit-P přechovávat-I přejíždět-I přejímat-I přejít-P přejet-P přejmenovat-P
    přejmout-P překážet-I překódovat-P překazit-P překládat-I překlenout-P překřikovat-I
    překřtít-P překonávat-I překonat-P překontrolovat-P překopnout-P překousnout-P
    překračovat-I překrýt-P překrývat-I překreslovat-I překrmovat-I překročit-P
    překroutit-P překrucovat-I překvapit-P překvapovat-I překypovat-I přelaďovat-I
    plešatět-I přeladit-P přeřadit-P přešetřit-P přešetřovat-I přeškolit-P přešlapávat-I
    přešlapovat-I přelévat-I přelézt-P přelít-P přeletět-P přeložit-P přelouskat-P
    přelstít-P přežít-P přežívat-I přemýšlet-I přeměřit-P přemalovávat-I přemalovat-P
    přeměňovat-I přeměnit-P přemístit-P přemítat-I přemisťovat-I přemlouvat-I
    přemluvit-P přemoci-P přemostit-P přenášet-I přenést-P přenechávat-I přenechat-P
    přeočkovat-P přeorganizovat-P přeorientovat-P přepadávat-I přepadat-I přepadnout-P
    přepínat-I přepisovat-I přeplácet-I přeplavit-P přeplňovat-I přeplnit-P
    přeplouvat-I přepnout-P přepočíst-P přepočítávat-I přepočítat-P přepojit-P
    přepracovávat-I přepracovat-P přepravit-P přepravovat-I přepsat-P přepustit-P
    přerazit-P přeregistrovat-P přerůst-P přerůstat-I přerozdělit-P přerozdělovat-I
    přerušit-P přerušovat-I přervat-P přesáhnout-P přesadit-P přesídlit-P přesahovat-I
    přesedlávat-I přesedlat-P přeskakovat-I přeskočit-P přeskupit-P přeslechnout-P
    přesměrovat-P přesmyknout-P přesouvat-I přespávat-I přespat-P přesprintovat-P
    přestát-P přestávat-I přestěhovat-P přestat-P přestavět-P přestavovat-I
    přestřelit-P přestřelovat-I přestřihnout-P přestoupit-P přestupovat-I přesunout-P
    přesunovat-I přesvědčit-P přesvědčovat-I přesytit-P přetáhnout-P přetápět-I
    přetahovat-I přetížit-P přetěžovat-I přetéci-P přetékat-I přetavit-P přetavovat-I
    přetisknout-P přetiskovat-I přetlačovat-I přetřásat-I přetřít-P přetlumočit-P
    přetočit-P přetopit-P přetransformovat-P přetrhnout-P přetrvávat-I přetrvat-P
    přetvářet-I přetvořit-P přeučit-P převádět-I převážet-I převážit-P převýšit-P
    převalit-P převalovat-I převažovat-I převést-P převézt-P převelet-P převládat-I
    převládnout-P převléci-P převrátit-P převracet-I převrhnout-P převtělit-P
    převychovávat-I převychovat-P převyšovat-I převyprávět-P převzít-P přezbrojit-P
    přezdívat-I přezkoumat-P přezkušovat-I přezouvat-I přičínět-I přičíst-P
    přičítat-I přičinit-P přičlenit-P přiběhnout-P přibírat-I přibarvovat-I
    přibít-P přibýt-P přibývat-I přiblížit-P přibližovat-I přibrat-P přibrzdit-P
    přicestovat-P přidávat-I přidělávat-I přidělat-P přidělit-P přidělovat-I
    přidat-P přidržet-P přidržovat-I přidružit-P přiházet-I přihazovat-I přihlásit-P
    přihřát-P přihlašovat-I přihlížet-I přihlédnout-P přihnat-P přihnojovat-I
    přihodit-P přihoršit-P přihrát-P přihrávat-I přihustit-P přicházívat-I přicházet-I
    přichycovat-I přichystat-P přijíždět-I přijímat-I přijít-P přijet-P přijmout-P
    přikázat-P přikývnout-P přikazovat-I přikládat-I přiklánět-I přiklonit-P
    přiklopit-P přikovat-P přikráčet-P přikrádat-I přikrýt-P přikročit-P přikusovat-I
    přikyvovat-I přilákat-P přišít-P přiřadit-P přišroubovat-P přiléhat-I přilétat-I
    přilétnout-P přilévat-I přiřítit-P přiřazovat-I přilepit-P přilepšit-P přilepovat-I
    přiletět-P přiřknout-P přiťuknout-P přiložit-P přiloudat-P přiživit-P přiživovat-I
    přimáčknout-P přimíchat-P přiměřit-P přimísit-P přimět-P přimknout-P přimlouvat-I
    přinášet-I přináležet-I přinést-P přinutit-P přiostřovat-I připadat-I připadnout-P
    připíchnout-P připínat-I připevňovat-I připevnit-P připisovat-I připlácet-I
    připlatit-P připlout-P připlynout-P připočíst-P připočítávat-I připočítat-P
    připojištěn-P připojistit-P připojit-P připojovat-I připomínat-I připomenout-P
    připouštět-I připoutávat-I připoutat-P připravit-P připravovat-I připsat-P
    připustit-P přirážet-I přirůstat-I přirovnávat-I přirovnat-P přislíbit-P
    přisoudit-P přispěchat-P přispět-P přispívat-I přistát-P přistávat-I přistěhovat-P
    přistavět-P přistavit-P přistavovat-I přistihnout-P přistřihnout-P přistoupit-P
    přistupovat-I přisunout-P přisuzovat-I přisvojit-P přitáhnout-P přitahovat-I
    přitížit-P přitěžovat-I přitéci-P přitékat-I přitisknout-P přitlačit-P přituhnout-P
    přitvrdit-P přitvrzovat-I přiučit-P přivádět-I přivážet-I přivírat-I přivést-P
    přivézt-P plivat-I přivítat-P přivazovat-I přivlastňovat-I přivlastnit-P
    přivřít-P plivnout-P přivodit-P přivolat-P přivolit-P přivrhnouti-P přivydělávat-I
    přivydělat-P přivyknout-P přizdobit-P přiznávat-I přiznat-P přizpůsobit-P
    přizpůsobovat-I přizvat-P plnit-I plodit-I plout-I plynout-I půjčit-P půjčovat-I
    půlit-I působit-I počíhat-P počínat-I počíst-P počastovat-P počít-P počítat-I
    počeštit-P počkat-P počůrat-P pobíhat-I pobírat-I pobýt-P pobývat-I pobavit-P
    pobízet-I pobodat-P pobouřit-P pobrat-P pobrukovat-I pobuřovat-I pocítit-P
    pociťovat-I podávat-I poděkovat-P podílet-I podařit-P podělit-P poděsit-P
    podat-P podít-P podívat-P podbarvovat-I podbízet-I podceňovat-I podcenit-P
    poddat-P podepisovat-I podepřít-P podepsat-P podezírat-I podezřívat-I podhodnotit-P
    podchytit-P podivit-P podivovat-I podjet-P podkládat-I podkopávat-I podkopat-P
    podřadit-P podřídit-P podléhat-I podříznout-P podlehnout-P podřezat-P podřimovat-I
    podřizovat-I podložit-P podlomit-P podmalovávat-I podmaňovat-I podmanit-P
    podmínit-P podmiňovat-I podminovat-P podněcovat-I podnítit-P podnikat-I
    podniknout-P podobat-I podotýkat-I podotknout-P podpisovat-I podplatit-P
    podpořit-P podporovat-I podráždit-P podražit-P podrazit-P podržet-P podrobit-P
    podrobovat-I podsouvat-I podstoupit-P podstrčit-P podstrojovat-I podstupovat-I
    podtrhávat-I podtrhnout-P podtrhovat-I podupávat-I podvádět-I podvázat-P
    podvést-P podvazovat-I podvolit-P podvolovat-I podvrhnout-P pohánět-I pohasnout-P
    pohlídat-P pohladit-P pohlížet-I pohlédnout-P pohřbít-P pohřbívat-I pohlcovat-I
    pohledávat-I pohledět-P pohřešovat-I pohltit-P pohnat-P pohnout-P pohodit-P
    pohořet-P pohoršit-P pohoršovat-I pohovořit-P pohrát-P pohrávat-I pohrdat-I
    pohrdnout-P pohroužit-P pohrozit-P pohupovat-I pohybovat-I pocházet-I pochlubit-P
    pochodit-P pochodovat-I pochopit-P pochovat-P pochroumat-P pochutnat-P pochválit-P
    pochvalovat-I pochybět-P pochybit-P pochybovat-I pochytat-P pochytit-P pojídat-I
    pojímat-I pojít-P pojednávat-I pojednat-P pojišťovat-I pojistit-P pojit-I
    pojmenovávat-I pojmenovat-P pojmout-P pokašlávat-I pokývat-P pokývnout-P
    pokazit-P pokládat-I poklást-P poklepat-P poklesávat-I poklesat-I poklesnout-P
    pokřikovat-I pokřivovat-I poklonit-P pokřtít-P pokořit-P pokoušet-I pokousat-P
    pokračovat-I pokračuje-I pokrčit-P pokrýt-P pokrývat-I pokročit-P pokulhávat-I
    pokusit-P pokutovat-I pokydat-P pokynout-P pořádat-I políbit-P pořídit-P
    poškodit-P poškozovat-I poškrábat-P poškrabat-P pošlapávat-I pošlapat-P
    pošpinit-P polapit-P pošramotit-P polarizovat-I polévat-I polít-P poštěstit-P
    poštvat-P pošušňávat-I polehávat-I polekat-P polemizovat-I polepit-P polepšit-P
    polepovat-I poletovat-I polevit-P polevovat-I pořezat-P politizovat-I pořizovat-I
    polknout-P pololhát-I položit-P polychromovat-B požádat-P požadovat-I požírat-I
    požít-P požívat-I požehnat-P pomáhat-I pomíjet-I pomýšlet-I pomalovat-P
    poměřovat-I pominout-P pomlčet-P pomlouvat-I pomluvit-P pomnožit-P pomnožovat-I
    pomočit-P pomoci-P pomodlit-P pomrznout-P pomstít-P pomuchlat-P pomyslet-P
    pomyslit-P ponížit-P poněmčit-P poněmčovat-I ponaučit-P ponechávat-I ponechat-P
    poničit-P ponořit-P ponořovat-I ponoukat-I poodhalit-P poodhalovat-P poodhrnout-P
    poodstoupit-P poohlédnout-P pookřát-P poopravit-P pootáčet-I pootočit-P
    popálit-P popásat-I popadat-P popadnout-P popíjet-I popírat-I popisovat-I
    popřát-P popřávat-I poplakat-P poplést-P popřít-P popřemýšlet-P popleskat-P
    poplivat-P poplynout-P popojíždět-I poporůst-P popovídat-P poprat-P popravit-P
    poprosit-P popsat-P poptávat-I popudit-P popularizovat-I poputovat-P porážet-I
    poradit-P poraňovat-I poranit-P porazit-P porcovat-I porůst-P porodit-P
    poroučet-I porovnávat-I porovnat-P porozumět-P portrétovat-I poručit-P porušit-P
    porušovat-I porvat-P posadit-P posílat-I posílit-P posít-P posbírat-P posečkat-P
    posedávat-I posedět-P posilnit-P posilovat-I poskakovat-I poskládat-P poskytnout-P
    poskytovat-I poslat-P poslechnout-P poslouchat-I posloužit-P posluhovat-I
    posmívat-I posoudit-P posouvat-I pospíchat-I pospíšit-P postačit-P postačovat-I
    postát-P postávat-I postěžovat-P postarat-P postavit-P postesknout-P postihnout-P
    postihovat-I postříkat-P postřílet-P postřehnout-P postřelit-P postoupit-P
    postrádat-I postrčit-P postrašit-P postrkovat-I postulovat-I postupovat-I
    posunkovat-I posunout-P posunovat-I posuzovat-I posvěcovat-I posvítit-P
    posvětit-P potácet-I potáhnout-P potápět-I potýkat-I potěšit-P potěžkávat-I
    potírat-I potýrat-P potit-I potkávat-I potkat-P potlačit-P potlačovat-I
    potřást-P potřísnit-P potřebovat-I potopit-P potrápit-P potrefit-P potrestat-P
    potrpět-I potrvat-P potulovat-I potupovat-I potvrdit-P potvrzovat-I poučit-P
    poučovat-I poukázat-P poukazovat-I pouštět-I použít-P používat-I pousmát-P
    poutat-I povážit-P povídat-I povědět-P povýšit-P povalit-P povařit-P pověřit-P
    pověřovat-I považovat-I pověsit-P povést-P povinout-P povinovat-I povšimnout-P
    povléci-P povolávat-I povolat-P povolit-P povolovat-I povozit-P povraždit-P
    povstávat-I povstat-P povyrůst-P povzbudit-P povzbuzovat-I povzdechnout-P
    povznášet-I povznést-P pozapomenout-P pozastavit-P pozastavovat-I pozatýkat-P
    pozbýt-P pozbývat-I pozdravit-P pozdravovat-I pozdržet-P pozdvihnout-P pozřít-P
    pozlobit-P pozůstavit-P pozměňovat-I pozměnit-P poznávat-I poznamenávat-I
    poznamenat-P poznat-P pozorovat-I poztrácet-P pozvat-P pozvedat-I pozvednout-P
    prát-I pracovávat-I pracovat-I prahnout-I praktikovat-I praštět-I praštit-P
    prýštit-I pramenit-I pranýřovat-I praskat-I prasknout-P pravit-P predikovat-I
    preferovat-I presentovat-I prezentovat-B prchat-I prchnout-P privatizovat-B
    pršet-I pročítat-I pročesávat-I probíhat-I proběhnout-P probíjet-I probírat-I
    probít-P problematizovat-I probleskovat-I probodnout-P probojovat-P probouzet-I
    probrat-P probrečet-P probudit-P procedit-P procitat-I procitnout-P proclít-P
    proclívat-I procvaknout-P procvičit-P procvičovat-I prodávat-I prodělávat-I
    prodělat-P prodírat-I prodat-P prodiskutovávat-I prodiskutovat-P prodloužit-P
    prodlužovat-I prodražit-P prodražovat-I prodrat-P produkovat-I profanovat-I
    profesionalizovat-I profičet-P profilovat-B profitovat-I profrčet-P prognózovat-I
    prohýbat-I prohazardovat-P prohazovat-I prohlásit-P prohlašovat-I prohlížet-I
    prohlédnout-P prohledávat-I prohledat-P prohřešit-P prohřešovat-I prohloubit-P
    prohlubovat-I prohodit-P prohrát-P prohrávat-I prohrnovat-I procházet-I
    proinvestovat-P projíždět-I projasnit-P projít-P projednávat-I projednat-P
    projektovat-I projet-P projevit-P projevovat-I prokázat-P prokazovat-I proklamovat-I
    proklínat-I proklestit-P prokňučet-P proklubat-P prokouknout-P prokousat-P
    prošetřit-P prošetřovat-I proškolit-P prošlapat-P prolamovat-I prolínat-I
    prošpikovat-P prolít-P proříznout-P prořeknout-P proležet-P proletět-P prořezat-P
    prolistovat-P prolnout-P proložit-P prolomit-P prožít-P prožívat-I prožvanit-P
    promíchat-P promíjet-I promýšlet-I proměřit-P proměňovat-I proměřovat-I
    proměnit-P promarnit-P promarodit-P promísit-P promítat-I promítnout-P promeškat-P
    prominout-P promlčet-P promlouvat-I promluvit-P promnout-P promoknout-P
    promrhat-P promyslet-P promyslit-P pronášet-I pronásledovat-I pronajímat-I
    pronajmout-P pronést-P pronikat-I proniknout-P proočkovat-P propálit-P propásnout-P
    propást-P propadat-I propadnout-P propagovat-I propíchat-P propíchnout-P
    propašovávat-I propašovat-P propékat-I propít-P proplácet-I proplést-P proplétat-I
    proplatit-P propůjčit-P propůjčovat-I propočíst-P propočítávat-I propojit-P
    propojovat-I propouštět-I propracovávat-I propracovat-P proprat-P propuknout-P
    propustit-P prorážet-I prorývat-I prorazit-P prorůst-P prorůstat-I prorokovat-I
    prosáknout-P prosadit-P prosít-P prosívat-I prosazovat-I prosekat-P prosit-I
    proskakovat-I proskočit-P proslýchat-I proslavit-P proslout-P proslovit-P
    prospat-P prospět-P prospívat-I prosperovat-I prostavět-P prostituovat-I
    prostříhat-P prostředkovat-I prostřelit-P prostoupit-P prostrčit-P prostudovat-P
    prostupovat-I prosvítat-I protáčet-I protáhnout-P protahovat-I protínat-I
    protéci-P protékat-I protežovat-I protestovat-I protiřečit-I protkat-P protlačit-P
    protřepat-P protnout-P protrhávat-I protrhnout-P protrpět-P proudit-I proukázati-P
    provádět-I provázet-I provalit-P prověřit-P prověřovat-I provést-P provézt-P
    provětrat-P provdat-P provinit-P provokovat-I provolávat-I provolat-P provozovat-I
    provzdušňovat-I prozkoumat-P prozradit-P prozrazovat-I psát-I psávat-I ptát-I
    ptávat-I publikovat-B pudit-I puknout-P pulírovat-I pusinkovat-I pustit-P
    putovat-I pykat-I pyšnit-I pytlačit-I ráčkovat-I rámovat-I radikalizovat-B
    radit-I radovat-I ranit-P rýpnout-P rýsovat-I ratifikovat-B razítkovat-I
    razit-I rdít-I reagovat-B realizovat-B recenzovat-I recitovat-I recyklovat-B
    redigovat-I redukovat-B reeditovat-B reexportovat-P referovat-B reflektovat-I
    reformovat-B regenerovat-B registrovat-B regulovat-I rehabilitovat-B reinvestovat-P
    rekapitulovat-B reklamovat-I rekonstruovat-B rekreovat-I rekrutovat-I rekvalifikovat-B
    rekvírovat-B relativizovat-I relaxovat-I režírovat-I remízovat-I remizovat-I
    reorganizovat-B replikovat-I representovat-I reprezentovat-I reprodukovat-B
    respektovat-I restaurovat-B restituovat-I restrukturalizovat-I retardovat-I
    retušovat-B revalvovat-B revidovat-I revokovat-B rezavět-I rezervovat-B
    rezignovat-B rezultovat-I riskovat-B růst-I různit-I rmoutit-I rodit-I rojit-I
    rokovat-I rotovat-I rovnat-I rozčílit-P rozčarovat-P rozčeřit-P rozčilovat-I
    rozčlenit-P rozbíhat-I rozběhnout-P rozbíjet-I rozbalit-P rozbít-P rozcupovat-P
    rozcvičovat-I rozdávat-I rozdílet-I rozdělit-P rozdělovat-I rozdat-P rozdmýchat-P
    rozdrobit-P rozdrtit-P rozeběhnout-P rozebírat-I rozebrat-P rozednívat-I
    rozehřát-P rozehnat-P rozehrát-P rozehrávat-I rozechvět-P rozechvívat-I
    rozejít-P rozepisovat-I rozepnout-P rozepsat-P rozesílat-I rozeslat-P rozesmát-P
    rozestavět-P rozestavit-P rozetnout-P rozevírat-I rozevřít-P rozeznávat-I
    rozeznat-P rozeznívat-I rozezpívat-I rozezvučet-P rozházet-P rozhýbat-P
    rozhlížet-I rozhlédnout-P rozhněvat-P rozhodit-P rozhodnout-P rozhodovat-I
    rozhořčit-P rozhořčovat-I rozhořet-P rozhorlit-P rozhostit-P rozhoupat-P
    rozhovořit-P rozhrnout-P rozcházet-I rozjásat-P rozjíždět-I rozjet-P rozkazovat-I
    rozkládat-I rozklížit-P rozklenout-P rozklepat-P rozkřičet-P rozkřiknout-P
    rozkmitat-P rozkolísat-P rozkrást-P rozkramařit-P rozkvést-P rozšířit-P
    rozlámat-P rozladit-P rozšiřovat-I rozškrábat-P rozšlehat-P rozléhat-I rozštěpit-P
    rozlítit-P rozříznout-P rozřeďovat-P rozlehnout-P rozřešit-P rozlepit-P
    rozletět-P rozlišit-P rozlišovat-I rozložit-P rozlomit-P rozloučit-P rozlučovat-I
    rozluštit-P rozžvýkávat-I rozžvýkat-P rozmáhat-I rozmíchat-P rozmýšlet-I
    rozmělňovat-I rozměnit-P rozmísťovat-I rozmístit-P rozmazat-P rozmetat-P
    rozmlátit-P rozmlouvat-I rozmnožit-P rozmnožovat-I rozmoci-P rozmotat-P
    rozmrznout-P rozmyslet-P rozmyslit-P roznášet-I rozněcovat-I roznést-P roznítit-P
    rozpálit-P rozpárat-P rozpadat-I rozpadnout-P rozpíjet-I rozpakovat-I rozpalovat-I
    rozpínat-I rozpitvávat-I rozplakat-P rozplývat-I rozplynout-P rozpočíst-P
    rozpočítávat-I rozpočítat-P rozpoltit-P rozpomínat-I rozpomenout-P rozpouštět-I
    rozpoutat-P rozpovídat-P rozpoznávat-I rozpoznat-P rozprášit-P rozprávět-I
    rozpracovávat-I rozpracovat-P rozprašovat-I rozprodávat-I rozprodat-P rozprostírat-I
    rozptýlit-P rozptylovat-I rozpustit-P rozrýt-P rozrazit-P rozrůst-P rozrůstat-I
    rozrůzňovat-I rozrušit-P rozsít-P rozstřílet-P rozstrkat-P rozsvěcet-I rozsvítit-P
    rozsypávat-I rozsypat-P roztáčet-I roztáhnout-P roztát-P roztahovat-I roztančit-P
    roztancovat-P roztavit-P roztlačit-P roztřídit-P roztleskat-P roztočit-P
    roztrhat-P roztrhnout-P roztrousit-P roztrpčit-P rozumět-I rozvádět-P rozvážit-P
    rozvázat-P rozvíjet-I rozvířit-P rozvažovat-I rozvěsit-P rozvést-P rozvézt-P
    rozvětvovat-I rozvinout-P rozvinovat-I rozvodnit-P rozvolnit-P rozvrátit-P
    rozvrhnout-P rozzářit-P rozzlobit-P ručit-I ruinovat-I rukovat-I rušívat-I
    rušit-I rvát-I rybařit-I sáhnout-P sýčkovat-I sálat-I sát-I sčítat-I sázet-I
    sídlit-I sahat-I sílit-I sankcionovat-I sít-I sbíhat-I sbalit-P sbírat-I
    sblížit-P scupovat-P scvrknout-P sdílet-I sdělit-P sdělovat-I sdružit-P
    sdružovat-I sečíst-P seběhnout-P sebrat-P sedávat-I sedat-I sedět-I sednout-P
    sehnat-P sehrát-P sehrávat-I sejít-P sejmout-P sekat-I sekundovat-I sešít-P
    seřadit-P seřídit-P seškrtat-P selektovat-I selhávat-I selhat-P seřizovat-I
    seřvat-P sežehnout-P sežrat-P semlít-P semnout-P sepisovat-I sepsat-P sepsout-P
    servírovat-B sesadit-P seskočit-P seskupovat-I sestávat-I sestavit-P sestavovat-I
    sestřelit-P sestoupit-P sestrojit-P sestupovat-I sestykovat-P sesunout-P
    sesypat-P setkávat-I setkat-P setřít-P setnout-P setrvávat-I setrvat-P sevřít-P
    seznámit-P seznamovat-I sezvat-P shánět-I shazovat-I shlížet-I shledávat-I
    shledat-P shluknout-P shlukovat-I shodit-P shodnout-P shodovat-I shořet-P
    shrnout-P shrnovat-I shromáždit-P shromažďovat-I scházívat-I scházet-I schnout-I
    schovávat-I schovat-P schválit-P schvalovat-I schylovat-I schytat-P signalizovat-I
    signovat-B simulovat-I situovat-I sjíždět-I sjednávat-I sjednat-P sjednocovat-I
    sjednotit-P sjet-P sjezdit-P skákat-I skórovat-B skandalizovat-I skandovat-I
    skartovat-B skýtat-I skládat-I sklánět-I skladovat-I skřípat-I sklízet-I
    sklidit-P skloňovat-I sklonit-P skloubit-P sklouzávat-I sklouznout-P skočit-P
    skolit-P skončit-P skonat-P skoncovat-P skrýt-P skrývat-I skrečovat-I skupovat-I
    skutálet-P skvět-I slábnout-I slíbit-P sladit-P slýchávat-I slýchat-I slévat-I
    slézat-I slézt-P slavit-I sledovat-I slehnout-P slepit-P slepovat-I slevit-P
    slevovat-I slibovat-I slitovat-P složit-P sloučit-P sloužívat-I sloužit-I
    slout-I slučovat-I slušet-I slunit-I slupnout-P slyšívat-I slyšet-I sžírat-I
    sžít-P smát-I smávat-I smíchat-P smýkat-I smířit-P směňovat-I směřovat-I
    smažit-I směnit-P směrovat-I smísit-P směstnat-P smést-P smět-I smítat-I
    smazat-P smekat-I smeknout-P smilovat-P smiřovat-I smlouvat-I smluvit-P
    smolit-I smontovat-P smrákat-I smrdět-I smrštit-P snášet-I snažívat-I snažit-I
    snížit-P sněžit-I snímat-I sníst-P snést-P snít-I snižovat-I snoubit-I sondovat-I
    soucítit-I soudcovat-I soudit-I souhlasit-I soupeřit-I sousedit-I soustřeďovat-I
    soustředit-P soutěžit-I souviset-I souznít-P spáchat-P spálit-P spářit-P
    spásat-I spát-I spadat-I spadnout-P spěchat-I spíchnout-P spílat-I spalovat-I
    spasit-P spékat-I spět-I spatřit-P spatřovat-I specializovat-B specifikovat-B
    spekulovat-I spelovat-I spiknout-I spisovat-I splácet-I spřádat-I spřátelit-P
    splakat-P splasknout-P splést-P splétat-I splatit-P splývat-I spříznit-P
    splňovat-I splnit-P splynout-P spočíst-P spočítat-P spočívat-I spočinout-P
    spojit-P spojovat-I spokojit-P spokojovat-I spořádat-P spolčit-P spoléhat-I
    spolehnout-P spořit-I spolknout-P spolufinancovat-I spolužít-I spolupůsobit-I
    spolupodílet-I spolupracovat-I spoluredigovat-I spolurozhodovat-I spoluvytvářet-I
    spoluzahájit-P spoluzaložit-P spolykat-P sponzorovat-I sportovat-I spotřebovávat-I
    spotřebovat-P spouštět-I spoutat-P spravit-P spravovat-I sprchnout-P sprchovat-I
    sprintovat-I sprovodit-P spustit-P srážet-I srazit-P srůst-P srůstat-I sroubit-P
    srovnávat-I srovnat-P stáčet-I stačívat-I stáhnout-P stačit-I stárnout-I
    stát-I stávat-I stávkovat-I stabilizovat-B stagnovat-I stíhat-I stahovat-I
    stěhovat-I stýkat-I stěžovat-I stínat-I stanout-P stanovit-P stanovovat-I
    starat-I stírat-I startovat-I stýskat-I stísnit-P stavět-I stavit-I sterilizovat-B
    sterilovat-B stihnout-P stimulovat-B stiskat-I stisknout-P střádat-I stlačit-P
    stlačovat-I střídávat-I střídat-I stříkat-I střílet-I střelit-P střežit-I
    střetávat-I střetnout-P stmívat-I stmelit-P stočit-P stonat-I stop-P stopovat-I
    stornovat-B stoupat-I stoupit-P stoupnout-P strádat-I strávit-P strachovat-I
    strčit-P strašit-I stranit-I stravovat-I strefit-P strhávat-I strhat-P strhnout-P
    strkat-I strnout-P strpět-P strukturovat-B studovat-I stupňovat-I stvořit-P
    stvrdit-P stvrzovat-I stydět-I subvencovat-I sugerovat-B sušit-I sužovat-I
    sumarizovat-I sundávat-I sundat-P sundavat-I sunout-I suplovat-I surfovat-I
    suspendovat-I svádět-I svářet-I svážet-I svázat-P svědčívat-I svědčit-I
    svědět-I svěřit-P svařovat-I svěřovat-I svažovat-I svírat-I svést-P svézt-P
    svítat-I svítit-I světit-I svatořečit-B svazovat-I svištět-I svitnout-P
    svléci-P svlékat-I svléknout-P svolávat-I svolat-P svolit-P svrbět-I svrbit-I
    svrhnout-P syčet-I symbolizovat-I sympatizovat-I synchronizovat-B syntetizovat-I
    sypat-I sytit-I tábořit-I táhnout-I tápat-I tát-I tázat-I tabuizovat-I tahat-I
    tíhnout-I tajit-I týkat-I taktizovat-I těšívat-I těšit-I tížit-I těžit-I
    tančit-I tancovat-I tankovat-I típnout-P týrat-I tasit-I tísnit-I téci-I
    téct-I týt-I taxikařit-I tečovat-I telefonovat-I telit-I tematizovat-I tenčit-I
    tendovat-I tepat-I terorizovat-I testovat-I tetovat-I textovat-I tipnout-P
    tipovat-I tisknout-I titulovat-I tkvít-I tlačit-I třást-I tříbit-I třídit-I
    tříštit-I třímat-I třaskat-I třísknout-P třepetat-I tleskat-I tlouci-I třpytit-I
    tlumit-I tlumočit-I tmět-I tmelit-I točit-I tolerovat-I tonout-I topit-I
    torpédovat-I toulat-I toužívat-I toužit-I trápívat-I trápit-I trávit-I tradovat-I
    trčet-I traktovat-I transformovat-B transplantovat-B transportovat-B trénovat-I
    tratit-I trefit-P trestat-I trhat-I trhnout-P triumfovat-I trmácet-I tropit-I
    troskotat-I troufat-I troufnout-P trousit-I trpět-I trpívat-I trucovat-I
    trumfnout-P trumfovat-I trvávat-I trvat-I tuhnout-I tušívat-I tušit-I tutlat-I
    tvářet-I tvářit-I tvarovat-I tvořívat-I tvořit-I tvrdívat-I tvrdit-I tyčit-I
    učívat-I učinit-P učit-I ubíhat-I uběhnout-P ubíjet-I ubírat-I ubít-P ubýt-P
    ubývat-I ubezpečit-P ubezpečovat-I ublížit-P ubližovat-I ubodat-P ubránit-P
    ubrat-P ubytovat-P ucítit-P ucpávat-I ucpat-P uctít-P uctívat-I udát-P udávat-I
    udýchat-P udělat-P udílet-I udělit-P udělovat-I udat-P udeřit-P udivit-P
    udivovat-I udržet-P udržovat-I udusit-P uhádnout-P uhájit-P uhasit-P uhasnout-P
    uhlídat-P uhnívat-I uhnízdit-P uhnout-P uhodit-P uhodnout-P uhrát-P uhradit-P
    uhranout-P uhrazovat-I uhynout-P ucházet-I uchýlit-P uchlácholit-P uchopit-P
    uchopovat-I uchovávat-I uchovat-P uchránit-P uchvátit-P uchvacovat-I uchylovat-I
    uchytit-P ujídat-I ujíždět-I ujímat-I ujasnit-P ujíst-P ujít-P ujednat-P
    ujet-P ujeti-P ujišťovat-I ujistit-P ujmout-P ukázat-P ukáznit-P ukamenovat-P
    ukapávat-I ukazovat-I ukládat-I uklízet-I uklidit-P uklidňovat-I uklidnit-P
    uklouznout-P ukočírovat-P ukojit-P ukončit-P ukončovat-I ukrást-P ukradnout-P
    ukrýt-P ukrývat-I ukusovat-I ukvapit-P ušít-P ušetřit-P ušklíbnout-P uškodit-P
    uškrtit-P ulít-P uštvat-P uříznout-P ulehčit-P ulehčovat-I ulehnout-P uletět-P
    ulevit-P uložit-P ulomit-P uloupnout-P ulovit-P ulpívat-I užírat-I užasnout-P
    užít-P užívat-I uživit-P umínit-P umanout-P umírat-I umísťovat-I umístit-P
    umýt-P umět-I umisťovat-I umlčet-P umlčovat-I umřít-P umocňovat-I umocnit-P
    umořovat-I umožňovat-I umožnit-P umoudřit-P umrtvit-P umučit-P unášet-I
    unést-P unavit-P unavovat-I unikat-I uniknout-P upálit-P upadat-I upadnout-P
    upalovat-I upamatovat-P upínat-I upírat-I upéci-P upít-P upevňovat-I upevnit-P
    upisovat-I uplácet-I upřít-P uplatit-P uplatňovat-I uplatnit-P uplývat-I
    upřednostňovat-I upřesňovat-I upřesnit-P uplynout-P upnout-P upomínat-I
    uposlechnout-P upotřebit-P upouštět-I upoutávat-I upoutat-P upozorňovat-I
    upozornit-P uprázdnit-P upravit-P upravovat-I uprchnout-P upsat-P upustit-P
    urážet-I určit-P určovat-I urazit-P urgovat-B urovnat-P urychlit-P urychlovat-I
    usadit-P usídlit-P usínat-I usazovat-I usedat-I usednout-P uschovávat-I
    uschovat-P usilovat-I uskladnit-P uskromnit-P uskrovnit-P uskutečňovat-I
    uskutečnit-P uslyšet-P usmát-P usmířit-P usměrňovat-I usměrnit-P usmívat-I
    usmiřovat-I usmrtit-P usnášet-I usnadňovat-I usnadnit-P usnést-P usnout-P
    usoudit-P usoužit-P uspěchat-P uspíšit-P uspat-P uspět-P uspokojit-P uspokojovat-I
    uspořádat-P uspořit-P ustálit-P ustát-P ustávat-I ustalovat-I ustanovit-P
    ustanovovat-I ustat-P ustavit-P ustavovat-I ustoupit-P ustrnout-P ustupovat-I
    usuzovat-I usvědčit-P utábořit-P utáhnout-P utahovat-I utajit-P utajovat-I
    utíkat-I utěšovat-I utírat-I utýrat-P utéci-P utichnout-P utišovat-I utkávat-I
    utkat-P utkvít-P utkvět-P utlačovat-I utřást-P utříbit-P utřídit-P utřít-P
    utlouci-P utloukat-I utlumit-P utlumovat-I utnout-P utonout-P utopit-P utrácet-I
    utratit-P utrhat-I utrhnout-P utržit-P utrousit-P utrpět-P utuchat-I utužovat-I
    ututlat-P utvářet-I utvořit-P utvrdit-P utvrzovat-I uvádět-I uvážit-P uvázat-P
    uváznout-P uvědomit-P uvědomovat-I uvalit-P uvařit-P uvěřit-P uvalovat-I
    uvažovat-I uvést-P uvítat-P uvěznit-P uvíznout-P uveřejňovat-I uveřejnit-P
    uvidět-P uvolit-P uvolňovat-I uvolnit-P uvrhnout-P uzákonit-P uzamknout-P
    uzavírat-I uzavřít-P uzdravit-P uzdravovat-I uzemnit-P uzlit-I uznávat-I
    uznat-P uzpůsobit-P uzrát-P uzurpovat-B vábit-I váhat-I válčit-I vážit-I
    vát-I vázat-I váznout-I vídat-I vědět-I vadívat-I vadit-I věšet-I věštit-I
    věřívat-I včleňovat-P valit-I vařit-I věřit-I valorizovat-B vandrovat-I
    vanout-I věnovat-I varovat-I věstit-I vést-I vévodit-I vézt-I vít-I výt-I
    vítat-I vítězit-I větrat-I větvit-I vězet-I věznit-I vběhnout-P vcítit-P
    vděčit-I vdát-P vdávat-I vdechovat-I vejít-P velebit-I velet-I velnout-P
    ventilovat-B vepsat-P verbovat-I verifikovat-B veselit-I vestavět-P vetkat-P
    vetknout-P vetřít-P vetovat-I vhazovat-I vhodit-P vcházet-I vidět-I vidívat-I
    vinit-I viset-I viz-I vjíždět-I vjet-P vkládat-I vklouznout-P vkrádat-I
    vkročit-P vládnout-I všímat-I vlát-I všívat-I všimnout-P vlastnit-I vléci-I
    vlétat-I vlézat-I vlézt-P vřít-I vštípit-P vštěpovat-I vřítit-P vlítnout-P
    vlepit-P vlepovat-I vletět-P vlnit-I vložit-P vloudit-P vloupat-P vžít-P
    vžívat-I vměšovat-I vměstnat-P vnášet-I vnadit-I vnímat-I vnést-P vnikat-I
    vniknout-P vnucovat-I vnutit-P vodit-I volávat-I volat-I volit-I vonět-I
    voperovat-P vozit-I vpálit-P vpadnout-P vpíjet-I vpašovat-P vplížit-P vplést-P
    vplétat-I vplout-P vplouvat-I vplynout-P vpouštět-I vpravit-P vpravovat-I
    vpustit-P vrážet-I vrátit-P vracívat-I vracet-I vrčet-I vraždit-I vrýt-P
    vrhat-I vrhnout-P vrcholit-I vrůst-P vrůstat-I vrtat-I vrtět-I vrzat-I vsázet-I
    vsadit-P vsítit-P vsazovat-I vsednout-P vsouvat-I vstát-P vstávat-I vstříknout-P
    vstřebávat-I vstřebat-P vstřelit-P vstoupit-P vstupovat-I vsunout-P vtáhnout-P
    vtahovat-I vtělit-P vtělovat-I vtípit-I vtírat-I vtěsnat-P vtipkovat-I vtisknout-P
    vtiskovat-I vtlačit-P vtrhnout-P vyčíslit-P vyčíslovat-P vyčíst-P vyčítat-I
    vyčerpávat-I vyčerpat-P vyčinit-P vyčistit-P vyčkávat-I vyčkat-P vyčleňovat-I
    vyčlenit-P vyčnívat-I vyúčtovat-P vyasfaltovat-P vyúsťovat-I vyústit-P vybídnout-P
    vybíhat-I vyběhat-P vyběhnout-P vybíjet-I vybalancovat-P vybírat-I vybarvit-P
    vybarvovat-I vybýt-P vybavit-P vybavovat-I vybízet-I vybičovat-I vyblednout-P
    vybočit-P vybočovat-I vybojovat-P vybourat-P vyboxovat-P vybrakovat-P vybrat-P
    vybrousit-P vybruslit-P vybudovat-P vybuchnout-P vybuchovat-I vybujet-P
    vyburcovat-P vycítit-P vycementovat-P vycestovat-P vycouvat-P vycucat-P
    vydávat-I vydědit-P vydýchat-P vydělávat-I vydělat-P vydařit-P vydělit-P
    vydělovat-I vydírat-I vyděsit-P vydat-P vydedukovat-P vydechnout-P vydechovat-I
    vydekorovat-P vydlabat-P vydlužit-P vydobýt-P vydolovat-P vydovádět-P vydražit-P
    vydrancovat-P vydržet-P vydržovat-I vydupat-P vyfasovat-P vyfotografovat-P
    vyfouknout-P vygradovat-P vygumovat-P vyháčkovat-P vyhánět-I vyházet-P vyhýbat-I
    vyhasínat-I vyhasnout-P vyhazovat-I vyhlásit-P vyhladit-P vyhlašovat-I vyhlížet-I
    vyhlédnout-P vyhřívat-I vyhlazovat-I vyhledávat-I vyhledat-P vyhloubit-P
    vyhmátnout-P vyhnat-P vyhnout-P vyhodit-P vyhodnocovat-I vyhodnotit-P vyhošťovat-I
    vyhořet-P vyhostit-P vyhotovit-P vyhoupnout-P vyhovět-P vyhovovat-I vyhrát-P
    vyhrávat-I vyhrabávat-I vyhrabat-P vyhradit-P vyhraňovat-I vyhranit-P vyhrkávat-I
    vyhrkat-I vyhrknout-P vyhrnout-P vyhrocovat-I vyhrožovat-I vyhrotit-P vyhubit-P
    vyhynout-P vycházet-I vychýlit-P vychladnout-P vychodit-P vychovávat-I vychovat-P
    vychrlit-P vychutnávat-I vychutnat-P vychvalovat-I vychytat-P vyinkasovat-P
    vyjádřit-P vyjadřovat-I vyjíždět-I vyjímat-I vyjasňovat-I vyjasnit-P vyjít-P
    vyjednávat-I vyjednat-P vyjet-P vyjevit-P vyjmenovat-P vyjmout-P vykácet-P
    vykázat-P vykazovat-I vykládat-I vyklíčit-P vyklízet-I vyklidit-P vykřiknout-P
    vykřikovat-I vyklopit-P vykloubit-P vyklubat-P vyklusávat-I vykolíkovat-P
    vykoledovat-P vykořenit-P vykompenzovat-P vykonávat-I vykonat-P vykopávat-I
    vykopat-P vykopnout-P vykouknout-P vykoupat-P vykoupit-P vykouzlit-P vykrádat-I
    vykrást-P vykrýt-P vykreslit-P vykrmit-P vykročit-P vykrvácet-P vykrystalizovat-P
    vykuchávat-I vykukovat-I vykupovat-I vykvést-P vykvétat-I vyšachovat-P vylíčit-P
    vylákat-P vylámat-P vyřadit-P vyřídit-P vyšetřit-P vyšetřovat-I vylíhnout-P
    vyříkat-P vyškemrat-P vyškolit-P vyškrtnout-P vyšlápnout-P vyšlapat-P vyšlehnout-P
    vyšlechtit-P vylamovat-I vyšperkovat-P vyšplhat-P vyšroubovat-P vyléčit-P
    vylétat-I vylétnout-P vylézat-I vylézt-P vylít-P vyšumět-P vyšvihnout-P
    vylízat-P vyříznout-P vyřazovat-I vylekat-P vyřešit-P vylepit-P vylepšit-P
    vylepšovat-I vyletět-P vyřezat-P vylhávat-I vylidnit-P vyřizovat-I vyřknout-P
    vylodit-P vyložit-P vylomit-P vylosovat-P vyloučit-P vyloupit-P vyloupnout-P
    vylovit-P vylučovat-I vylustrovat-P vyluxovat-P vyžádat-P vyžadovat-I vymáčknout-P
    vymáhat-I vymámit-P vymýšlet-I vyměřit-P vymalovat-P vyměňovat-I vyměřovat-I
    vymanévrovat-P vymanit-P vymínit-P vyměnit-P vymírat-I vymést-P vymýtit-P
    vymývat-I vymazat-P vymetat-I vymezit-P vymezovat-I vymiňovat-I vymizet-P
    vymknout-P vymřít-P vymlouvat-I vymluvit-P vymočit-P vymoci-P vymodelovat-P
    vymodlit-P vymrštit-P vymstít-P vymycovat-I vymykat-I vymyslet-P vymyslit-P
    vynášet-I vynásobit-P vynadat-P vynahradit-P vynacházet-I vynakládat-I vynalézat-I
    vynaleznout-P vynaložit-P vynést-P vyndávat-I vyndat-P vynechávat-I vynechat-P
    vynikat-I vyniknout-P vynořit-P vynořovat-I vynucovat-I vynulovat-P vynutit-P
    vyobrazit-P vyoperovat-P vyostřit-P vyostřovat-I vypáčit-P vypálit-P vypátrat-P
    vypadávat-I vypadat-I vypadnout-P vypíchnout-P vypařit-P vypínat-I vypískat-P
    vypěstovat-P vypít-P vypiplat-P vypisovat-I vyplácet-I vyplašit-P vyplatit-P
    vyplýtvávat-I vyplavat-P vyplývat-I vyplenit-P vyplivnout-P vyplňovat-I
    vyplnit-P vyplout-P vyplouvat-I vyplynout-P vypůjčit-P vypůjčovat-I vypnout-P
    vypočíst-P vypočítávat-I vypočítat-P vypořádávat-I vypořádat-P vypomáhat-I
    vypomoci-P vypouštět-I vypovídat-I vypovědět-P vyprávět-I vypracovávat-I
    vypracovat-P vyprat-P vypravit-P vypravovat-I vyprazdňovat-I vypreparovat-P
    vyprchat-P vypršet-P vyprodávat-I vyprodat-P vyprodukovat-P vyprofilovat-P
    vyprojektovat-P vyprošťovat-I vyprostit-P vyprovázet-I vyprovodit-P vyprovokovat-P
    vypsat-P vyptávat-I vyptat-I vypudit-P vypuknout-P vypumpovat-P vypustit-P
    vypuzovat-I vyrábět-I vyrážet-I vyrýt-P vyrazit-P vyrůst-P vyrůstat-I vyrobit-P
    vyrojit-P vyrovnávat-I vyrovnat-P vyrozumět-P vyrozumívat-I vyrukovat-P
    vyrušit-P vyrvat-P vysávat-I vysázet-P vysadit-P vysílat-I vysazovat-I vysedávat-I
    vysedat-I vyschnout-P vyskakovat-I vyskočit-P vyskytnout-P vyskytovat-I
    vyslýchat-I vyslat-P vysledovat-P vyslechnout-P vysloužit-P vyslovit-P vyslovovat-I
    vyslyšet-P vysmát-P vysmívat-I vysmeknout-P vysnívat-I vysouvat-I vyspat-P
    vyspět-P vyspravit-P vysrat-P vystačit-P vystačovat-I vystěhovat-P vystýlat-I
    vystartovat-P vystavět-P vystavit-P vystavovat-I vystihnout-P vystihovat-I
    vystřídat-P vystříhat-B vystřílet-P vystřízlivět-P vystřelit-P vystřelovat-I
    vystřihávat-I vystřihnout-P vystopovat-P vystoupat-P vystoupit-P vystrčit-P
    vystrašit-P vystrkovat-I vystrojit-P vystudovat-P vystupňovat-P vystupovat-I
    vysušit-P vysunout-P vysvítat-I vysvětit-P vysvětlit-P vysvětlovat-I vysvitnout-P
    vysvobodit-P vysvobozovat-I vysychat-I vysypat-P vytáčet-I vytáhnout-P vytýčit-P
    vytápět-I vytahat-P vytahovat-I vytýkat-I vytížit-P vytěžit-P vytanout-P
    vytasit-P vytěsnit-P vytéci-P vytečkovat-P vytempovat-P vytesávat-I vytesat-P
    vytetovat-P vytipovat-P vytisknout-P vytknout-P vytlačit-P vytlačovat-I
    vytříbit-P vytřídit-P vytřískat-P vytloukat-I vytočit-P vytrácet-I vytratit-P
    vytrejdovat-P vytrhávat-I vytrhat-P vytrhnout-P vytrhovat-I vytrpět-P vytrucovat-P
    vytrvávat-I vytrvat-P vytušit-P vytvářet-I vytvarovat-P vytvořit-P vytyčit-P
    vytyčovat-I vytypovat-I vyučit-P vyučovat-I využít-P využívat-I vyvádět-I
    vyvážet-I vyvážit-P vyváznout-P vyvíjet-I vyvalit-P vyvařovat-I vyvažovat-I
    vyvěrat-I vyvarovat-P vyvěsit-P vyvést-P vyvézt-P vyvinout-P vyvinovat-I
    vyvlastňovat-I vyvlastnit-P vyvléknout-P vyvodit-P vyvolávat-I vyvolat-P
    vyvozovat-I vyvrátit-P vyvracet-I vyvražďovat-I vyvraždit-P vyvrcholit-P
    vyvstávat-I vyvstat-P vyvzdorovat-P vyzářit-P vyzařovat-I vyzývat-I vyzbrojit-P
    vyzbrojovat-I vyzdobit-P vyzdvihnout-P vyzdvihovat-I vyzkoušet-P vyzkoumat-P
    vyznačit-P vyznačovat-I vyznávat-I vyznamenat-P vyznat-P vyznít-P vyznívat-I
    vyzobávat-I vyzpívat-I vyzpovídat-P vyzrát-P vyzradit-P vyztužit-P vyzvánět-I
    vyzvídat-I vyzvědět-P vyzvat-P vyzvedávat-I vyzvednout-P vzít-P vzývat-I
    vzbouřit-P vzbouzet-I vzbudit-P vzbuzovat-I vzdálit-P vzdát-P vzdávat-I
    vzdělávat-I vzdělat-P vzdalovat-I vzdorovat-I vzdychat-I vzdychnout-P vzedmout-P
    vzejít-P vzepřít-P vzhlížet-I vzhlédnout-P vzchopit-P vzkázat-P vzkazovat-I
    vzklíčit-P vzkřísit-P vzlétat-I vzlétnout-P vznášet-I vznést-P vznítit-P
    vznikat-I vzniknout-P vzpamatovávat-I vzpamatovat-P vzpínat-I vzpírat-I
    vzplanout-P vzpomínat-I vzpomenout-P vzrůst-P vzrůstat-I vzrušit-P vzrušovat-I
    vztáhnout-P vztahovat-I vztyčit-P vztyčovat-I začínat-I začíst-P začít-P
    zábst-I začervenat-P začleňovat-I záležet-I začlenit-P zářit-I zálohovat-B
    zápasit-I zápolit-I zaúčtovat-P zásobovat-I zaútočit-P závidět-I záviset-I
    závodit-I závojovat-I zaběhnout-P zabíjet-I zabalit-P zabalovat-I zabírat-I
    zabarikádovat-P zabarvit-P zabít-P zabývat-I zabavit-P zabavovat-I zaberanit-P
    zabetonovat-P zabezpečit-P zabezpečovat-I zablátit-P zabředat-I zabřednout-P
    zablokovat-P zabloudit-P zabodnout-P zabodovat-P zabolet-P zabořit-P zabouchnout-P
    zabránit-P zabraňovat-I zabrat-P zabrnkat-P zabrzdit-P zabudovávat-I zabudovat-P
    zabydlet-P zabydlovat-I zacelit-P zacelovat-I zacloumat-P zacpávat-I zadávat-I
    zadat-P zadlužit-P zadlužovat-I zadministrovat-P zadout-P zadrhnout-P zadržet-P
    zadržovat-I zadrnčet-P zčervenat-P zafixovat-P zafungovat-P zahájit-P zahálet-I
    zahánět-I zahýbat-I zahajovat-I zahalit-P zahalovat-I zahanbit-P zahaprovat-P
    zahřát-P zahladit-P zahlédnout-P zahřívat-I zahlazovat-I zahledět-P zahltit-P
    zahnat-P zahnout-P zahodit-P zahojit-P zahrát-P zahrávat-I zahrabat-P zahradit-P
    zahrazovat-I zahrnout-P zahrnovat-I zahrozit-P zahryznout-P zahubit-P zahustit-P
    zahynout-P zacházel-I zacházet-I zachovávat-I zachovat-P zachránit-P zachraňovat-I
    zachtít-P zachumlat-P zachvátit-P zachvět-P zachycovat-I zachytávat-I zachytat-P
    zachytit-P zachytnout-P zainteresovat-P zčitelnit-P zajásat-P zajíždět-I
    zajímat-I zajít-P zajet-P zajišťovat-I zajiskřit-P zajistit-P zajmout-P
    zakázat-P zakódovat-P zakalkulovat-P zakazovat-I zakládat-I zaklít-P zakleknout-P
    zaklepat-P zakřičet-P zakřivovat-I zaknihovat-P zakolísat-P zakořenit-P
    zakomponovat-P zakončit-P zakončovat-I zakonzervovat-P zakopat-P zakopnout-P
    zakormidlovat-P zakotvit-P zakotvovat-I zakoukat-P zakoupit-P zakousnout-P
    zakrýt-P zakrývat-I zakreslit-P zakrnět-P zakročit-P zakročovat-I zaktivizovat-P
    zaktualizovat-P zakuklit-P zakupovat-I zakusovat-I zakutat-P zašátrat-P
    zařaďovat-I zašívat-I zalíbit-P zařadit-P zařídit-P zašeptat-P zašermovat-P
    zaškolit-P zaškrtnout-P zalarmovat-P zalévat-I zalézat-I zalézt-P zalít-P
    zaštítit-P zaštiťovat-I zaříznout-P zařazovat-I zaleknout-P zařeknout-P
    zalepit-P zařezávat-I zalichotit-P zalitovat-P zařizovat-I založit-P zalomit-P
    zařvat-P zalyžovat-P zažádat-P zažíhat-I zažalovat-P zažít-P zažívat-I zažehnat-P
    zamáčknout-P zamávat-P zamíchat-P zamýšlet-I zamířit-P zaměřit-P zaměňovat-I
    zaměřovat-I zaměnit-P zamanout-P zamaskovat-P zaměstnávat-I zaměstnat-P
    zamést-P zamítat-I zamítnout-P zameškat-P zametat-I zamezit-P zamezovat-I
    zamilovat-P zamknout-P zamlčet-P zamlčovat-I zamlžovat-I zamlouvat-I zamluvit-P
    zamnout-P zamořit-P zamotat-P zamručet-P zamrznout-P zamykat-I zamyslet-P
    zamyslit-P zanášet-I zanést-P zanedbávat-I zanedbat-P zanechávat-I zanechat-P
    zaneprázdnit-P zanikat-I zaniknout-P zanořovat-I zaobírat-P zaoblit-P zaokrouhlit-P
    zaokrouhlovat-I zaopatřovat-I zaostávat-I zaostat-P zapálit-P zapadávat-I
    zapadat-I zapadnout-P zapíchnout-P zapalovat-I zapamatovat-P zapínat-I zaparkovat-P
    zapět-P zapečetit-P zapisovat-I zapřáhnout-P zapříčinit-P zaplakat-P zaplašit-P
    zaplašovat-I zaplést-P zaplétat-I zapřít-P zaplatit-P zaplavat-P zaplavit-P
    zaplavovat-I zaplňovat-I zaplnit-P zapůjčit-P zapůjčovat-I zapůsobit-P zapnout-P
    započíst-P započít-P započítávat-I započítat-P zapochybovat-P zapojit-P
    zapojovat-I zapomínat-I zapomenout-P zaposlouchat-P zapotit-P zapovídat-P
    zapovědět-P zapracovávat-I zapraskat-P zaprodávat-I zaprotokolovat-P zapsat-P
    zapudit-P zapustit-P zarážet-I zarámovat-P zaradovat-P zírat-I zarývat-I
    zarazit-P zareagovat-P zaregistrovat-P zariskovat-P zarůstat-P zarmoutit-P
    zaručit-P zaručovat-I zasáhnout-P zúčastňovat-I zúčastnit-P zasadit-P zasahovat-I
    zasílat-I zasít-P zúčtovat-P zasazovat-I zasedat-I zasednout-P zaseknout-P
    získávat-I získat-P zaskočit-P zaslat-P zaslechnout-P zaslepit-P zaslepovat-I
    zasloužit-P zasluhovat-I zúžit-P zasmát-P zasmečovat-P zasout-P zaspat-P
    zúročit-P zastávat-I zastínit-P zastarávat-I zastírat-I zastat-P zastavět-P
    zastavit-P zastavovat-I zastihnout-P zastihovat-I zastiňovat-I zastřít-P
    zastřešovat-I zastřelit-P zastoupit-P zastrašit-P zastrašovat-I zastrkávat-I
    zastupovat-I zastydět-P zasvítit-P zasvětit-P zasypat-P zatáčet-I zatáhnout-P
    zatápět-I zatajit-P zatajovat-I zatýkat-I zatížit-P zatěžovat-I zatančit-P
    zatarasit-P zatékat-I zatavit-P zatelefonovat-P zatemňovat-I zatemnit-P
    zateplovat-I zatknout-P zatlačit-P zatřást-P zatřepat-P zatleskat-P zatlouci-P
    zatnout-P zatočit-P zatopit-P zatoulat-P zatoužit-P zatracovat-I zatrénovat-P
    zatratit-P zatrhnout-P zatrnout-P zatroubit-P zatvářit-P zaujímat-I zaujmout-P
    zauzlovat-P zavádět-I zaváhat-P zavážet-I zavánět-I zavát-P zavázat-P zavadit-P
    zavěšovat-I zavalit-P zavírat-I zavěsit-P zavést-P zavézt-P zavítat-P zavazovat-I
    zavděčit-P zavdávat-I zavdat-P zavelet-P zavinit-P zavinout-P zavládnout-P
    zavlát-P zavléci-P zavřít-P zavolat-P zavraždit-P zavrhnout-P zavrhovat-I
    završit-P završovat-I zavrtávat-I zavrtět-P zavzpomínat-P zazářit-P zazlít-P
    zazlívat-I zaznamenávat-I zaznamenat-P zaznít-P zaznívat-I zazpívat-P zazvonit-P
    zbankrotovat-P zbít-P zbýt-P zbývat-I zbavit-P zbavovat-I zbláznit-P zblbnout-P
    zblokovat-P zbobtnat-P zbohatnout-P zbořit-P zbožštit-P zbožňovat-I zbortit-P
    zbourat-P zbrázdit-P zbrojit-I zbrousit-P zbrzdit-P zbudovat-P zbuntovat-P
    zbystřit-P zcizit-P zdát-I zdávat-I zdědit-P zdařit-P zdaňovat-I zdanit-P
    zdecimovat-P zdeformovat-P zdemolovat-P zdiskreditovat-P zdřímnout-P zdůrazňovat-I
    zdůraznit-P zdůvodňovat-I zdůvodnit-P zdobit-I zdokonalit-P zdokonalovat-I
    zdolávat-I zdolat-P zdomácnět-P zdráhat-I zdražit-P zdražovat-I zdramatizovat-P
    zdravit-I zdržet-P zdržovat-I zdrsnit-P zdrtit-P zdvihnout-P zdvojit-P zdvojnásobit-P
    zdvojnásobovat-I zefektivňovat-I zešedivět-I zeštíhlet-P zeštíhlit-P zeštíhlovat-I
    zelenat-I zemřít-P zepsout-P zeptat-P zesílit-P zesilovat-I zeslabit-P zeslabovat-I
    zesměšňovat-I zesměšnit-P zestárnout-P zestátňovat-I zestátnit-P zestručnit-P
    zet-I zevšeobecňovat-I zezelenat-P zfalšovat-P zfilmovat-P zformovat-P zformulovat-P
    zhýčkat-P zhanobit-P zhasínat-I zhasnout-P zhlížet-P zhlédnout-P zhlavovat-P
    zhřešit-P zhmotňovat-I zhmotnit-P zhodnocovat-I zhodnotit-P zhojit-P zhořknout-P
    zhoršit-P zhoršovat-I zhospodárnit-P zhostit-P zhotovit-P zhoustnout-P zhroutit-P
    zhrudkovatět-P zhubnout-P zhušťovat-I zhumanizovat-P zhysterizovat-P zchladit-P
    zchladnout-P zideologizovat-P zimovat-I zinscenovat-P zintenzívnit-P zjasňovat-I
    zjednávat-I zjednat-P zjednodušit-P zjednodušovat-I zjevit-P zjevovat-I
    zjišťovat-I zjistit-P zjizvit-P zkalkulovat-P zkazit-P zklamat-P zklidňovat-I
    zklidnit-P zkřivit-P zkolabovat-P zkolaudovat-P zkombinovat-P zkompletovat-P
    zkomplikovat-P zkomponovat-P zkoncentrovat-P zkonfiskovat-P zkonsolidovat-P
    zkonstruovat-P zkontrolovat-P zkonzumovat-P zkoordinovat-P zkopat-P zkorumpovat-P
    zkoušet-I zkoumat-I zkrášlit-P zkrátit-P zkracovat-I zkrachovat-P zkreslit-P
    zkreslovat-I zkrotit-P zkultivovat-P zkusit-P zkvašovat-I zkvalitňovat-I
    zkvalitnit-P zlákat-P zlíbit-P zříci-P zřídit-P zříkat-I zlanařit-P zřít-I
    zřítit-P zředit-P zlehčovat-I zřeknout-P zlepšit-P zlepšovat-I zlevňovat-I
    zlevnit-P zlikvidovat-P zřizovat-I zlobívat-I zlobit-I zlořečit-I zlomit-P
    zůstávat-I zůstat-P zželet-P zmáčknout-P zmást-P zmýdelňovat-I změkčet-P
    změkčit-P změkčovat-I zmalátnit-P zmalířštět-P zmařit-P zmýlit-P změřit-P
    zmalomyslnět-P zmanipulovat-P zmínit-P změnit-P zmapovat-P zmírat-I zmírňovat-I
    zmírnět-P zmarnit-P zmírnit-P zmasakrovat-P zmítat-I zmehnout-P zmenšit-P
    zmenšovat-I zmiňovat-I zmizet-P zmlátit-P zmnohonásobit-P zmnožit-P zmnožovat-I
    zmobilizovat-P zmoci-I zmocňovat-I zmocnět-P zmocnit-P zmodernizovat-P zmrazit-P
    zmrazovat-I zmrzačit-P zmrznout-P značívat-I značit-I značkovat-I známkovat-I
    znárodňovat-I znárodnit-P znásilňovat-I znásilnit-P znásobit-P znát-I znávat-I
    znázorňovat-I znázornit-P zněkolikanásobit-P znamenat-I znít-I znečišťovat-I
    znečistit-P znehodnocovat-I znehodnotit-P znechucovat-I znechutit-P znejistět-P
    znejistit-P zneklidňovat-I zneklidnět-P zneklidnit-P znelíbit-P zneškodňovat-I
    zneškodnit-P znemožňovat-I znemožnit-P znepřátelit-P znepříjemňovat-I znepříjemnit-P
    znepokojit-P znepokojovat-I znervózňovat-I znervóznit-P znesnadňovat-I znesvěcovat-I
    znetvořit-P zneuctít-P zneužít-P zneužívat-I znevážit-P znevýhodňovat-I
    znevýhodnit-P znevažovat-I zničit-P zničovat-I znivelizovat-P znormalizovat-P
    znovuobjevit-P znovuobjevovat-I znovuožívat-I znovuotevřít-P zobecňovat-I
    zobecnit-P zobchodovat-P zobrazit-P zobrazovat-I zocelovat-I zodpovídat-I
    zodpovědět-P zohavit-P zohledňovat-I zohlednit-P zopakovat-P zorganizovat-P
    zorientovat-P zosobňovat-I zostřit-P zostřovat-P zotavit-P zotavovat-I zotvírat-P
    zoufat-B zout-I zpěčovat-I zpanikařit-P zpívávat-I zpívat-I zpečetit-P zpeněžit-P
    zpestřit-P zpestřovat-I zpevňovat-I zpevnit-P zpříjemnit-P zpřísňovat-I
    zpřísnět-P zpřísnit-P zpřístupňovat-I zpřístupnět-P zpřístupnit-P zpřítomňovat-I
    zpřehlednit-P zpřesňovat-I zpřesnit-P zpřetrhat-P zplnomocňovat-I zplnomocnit-P
    zplodit-P zploštit-P způsobit-P způsobovat-I zpodobnit-P zpohodlnět-P zpohodlnit-P
    zpochybňovat-I zpochybnit-P zpolitizovat-P zpožďovat-I zpomalit-P zpomalovat-I
    zpovídat-I zpozdit-P zpozorovat-P zpracovávat-I zpracovat-P zpravit-P zprivatizovat-P
    zprůhlednit-P zprůměrovat-P zprůzračnit-P zprofanovat-P zprošťovat-I zpronevěřit-P
    zprostit-P zprostředkovávat-I zprostředkovat-P zprovoznit-P zpuchřet-P zpustnout-P
    zpustošit-P zpytovat-I zračit-I zrát-I zracionalizovat-P zradit-P zraňovat-I
    zranit-P zrazovat-I zrcadlit-I zrealizovat-P zredukovat-P zrekapitulovat-P
    zrekonstruovat-P zrentgenovat-P zreprodukovat-P zrestaurovat-P zrevidovat-P
    zrezivět-I zrůžovět-P zrodit-P zruinovat-P zrušit-P zrušovat-I zrychlit-P
    zrychlovat-I ztělesňovat-I ztělesnit-P ztížit-P ztěžknout-P ztěžovat-I ztenčit-P
    ztenčovat-I ztichnout-P ztišit-P ztišovat-I ztlouci-P ztlumit-P ztotožňovat-I
    ztotožnit-P ztrácet-I ztrapnit-P ztratit-P ztrestat-P ztrojnásobit-P ztroskotávat-I
    ztroskotat-P ztrpčovat-I ztuhnout-P ztvárnit-P ztvrdit-P zuřit-I zužitkovat-P
    zužovat-I zurčet-I zvážit-P zvěčnit-P zvát-I zvědět-P zvadnout-P zvýhodňovat-I
    zvýhodnit-P zvýšit-P zvalchovat-P zvažovat-I zvýraznět-P zvýraznit-P zvěstovat-I
    zvítězit-P zvětšit-P zvětšovat-I zvedat-I zvednout-P zvelebit-P zvelebovat-I
    zveřejňovat-I zveřejnět-P zveřejnit-P zveličovat-I zviditelňovat-I zviditelnit-P
    zvládat-I zvládnout-P zvolat-P zvolit-P zvolňovat-I zvonit-I zvrátit-P zvracet-I
    zvrhnout-P zvučet-I zvykat-I zvyknout-P zvyšovat-I);

my %aspect_of;

foreach my $verb (@verbs) {
    my ( $mlemma, $aspect ) = split '-', $verb;
    $aspect_of{$mlemma} = $aspect;
}

sub get_verb_aspect {
    my $lemma = shift;
    
    # normalize reflexive t-lemmas
    $lemma =~ s/_s[ie]$//;
    # normalize numbered m-lemmas
    $lemma = Treex::Tool::Lexicon::CS::truncate_lemma($lemma, 1); 
    
    my $aspect = $aspect_of{$lemma};
    if ( defined $aspect ) {
        return $aspect;
    }
    else {
        return 'P';    # mezi slovesy nepokrytymi slovnikem by melo byt vic dokonavych
    }
}

1;

#TODO (MP): rewrite Treex::Tool::Lexicon::CS::Aspect from scratch

__END__

=pod

=head1 NAME

Treex::Tool::Lexicon::CS::Aspect

=head1 SYNOPSIS

use Treex::Tool::Lexicon::CS::Aspect;
if (    Treex::Tool::Lexicon::CS::Aspect::get_verb_aspect('čekat')     eq 'P'
    and Treex::Tool::Lexicon::CS::Aspect::get_verb_aspect('čekávat')   eq 'I'
    and Treex::Tool::Lexicon::CS::Aspect::get_verb_aspect('adresovat') eq 'B')
{
    print "OK\n";    
}

=head1 DESCRIPTION

Recognizes an aspect of czech verbs: perfective=P, imperfective=I, biaspectual=B.
Temporary trivial implementation with hash of most frequent verbs and no rules.

=cut

# Copyright 2008 Zdenek Zabokrtsky, Martin Popel
