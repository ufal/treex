package Treex::Tool::Tagger::Simple::FR;
use utf8;
use Moose;
use Treex::Core::Common;
with 'Treex::Tool::Tagger::Role';
use autodie;

use Treex::Core::Resource qw(require_file_from_share);

#has dictionary => (
#    is            => 'ro',
#    isa           => 'HashRef',
#    lazy_build    => 1,
#    documentation => 'French dictionary lexique-dicollecte',
#);
#
#has common_words => (
#    is            => 'ro',
#    isa           => 'HashRef',
#    lazy_build    => 1,
#    documentation => 'tags of common words',
#);
my $dictionary = _build_dictionary();
my $common_words = _build_common_words();

sub tag_and_lemmatize_sentence {
    my ( $self, @words ) = @_;
   
    my @tags   = map { $self->tag_word($_) } @words;
    my @lemmas = map { $self->lemmatize_word($_) } @words;
    return ( \@tags, \@lemmas );
}

sub lemmatize_word {
    my ( $self, $word ) = @_;
    log_fatal "h3" if !defined $word;
    return $dictionary->{$word}{lemma} // lc $word;
}

sub tag_word {
    my ( $self, $word ) = @_;

    # lowercase word
    $word =~ tr/ÀÂÉÈÊËÎÏÔÖÙÛÜÇA-Z/àâéèêëîïôöùûüça-z/;

    # Check common words
    my $tag = $common_words->{$word};
    return $tag if defined $tag;

    # Check dictionary
    $tag = $dictionary->{$word}{my_tag} || '';
    return $tag if $tag; #eq 'verb' || $tag eq 'noun';

    # Check numerals
    $word =~ s/([^_]+)_.*/$1/;
    return 'num' if $word =~ /\d/;

    # try 4-character suffix at first
    my $adj_score = adj_score( $word, 4 );
    my $noun_score = noun_score( $word, 4 );
    return 'adj'  if $adj_score > $noun_score;
    return 'noun' if $noun_score > 0;

    #if not found from 4-char suffix, try to look for 3-char suffix
    $adj_score = adj_score( $word, 3 );
    $noun_score = noun_score( $word, 3 );
    return 'adj'  if $adj_score > $noun_score;
    return 'noun' if $noun_score > 0;

    # then try to identify verbs
    my $verb_score = verb_score($word);
    return 'verb' if $verb_score > 0;

    # fallback -- noun
    return 'noun';
}

sub _build_dictionary {
    #to be changed
    use Treex::Core::Resource;
    my $dict_file = Treex::Core::Resource::require_file_from_share(
        'data/models/simple_tagger/fr/lexique-dicollecte-fr-v3.8.LT.txt',
        'Treex::Tool::Tagger::Simple::FR'
    );

    open my $dict, "<:encoding(UTF-8)", $dict_file;
    my %fr_dict;
    while (<$dict>) {
        my $line = $_;
        chomp $line;

        # skip comments
        next if $line =~ /#.*/;

        my ( $form, $lemma, $tag ) = split /\t/, $line;
        if ( defined($form) && $form ne "" ) {

            # toto nie je dobre, pre rozne tagy moze byt odlisna lemma!!
            $fr_dict{$form}{lemma} = $lemma;
            $fr_dict{$form}{tag}   = $tag;

            #           @tags = split(/[\[\|]/,$tag)
            my $my_tag = "";
            if ( $tag =~ /^\[v/ || $tag =~ /^\[être/ || $tag =~ /^\[avoir/ || $tag =~ /\[loc.verb/ ) {
                $my_tag = "verb";
            }
            elsif ( $tag =~ /\[adv/ || $tag =~ /\[loc.adv/ ) {
                $my_tag = "adv";
            }
            elsif ( $tag =~ /\[géo/ || $tag =~ /\[nm/ || $tag =~ /\[nf/ || $tag =~ /\[patr/ || $tag =~ /\[pref/ || $tag =~ /\[prem/ ) {
                $my_tag = "noun"
            }
            elsif ( $tag =~ /\[interj/ ) {
                $my_tag = "interj"
            }
            elsif ( $tag =~ /\[nb/ ) {
                $my_tag = "num"
            }

            $fr_dict{$form}{my_tag} = $my_tag;
        }

    }
    close $dict;

    log_info("dict loaded successfully\n");
    return ( \%fr_dict );
}

sub _build_common_words {
    return {

        # slovesa, verba
        "est"    => "verb",
        "était" => "verb",
        "avait"  => "verb",
        "dit"    => "verb",    #
        "être"  => "verb",
        "fait"   => "verb",
        "faire"  => "verb",

        # aux
        "a"     => "aux",      # "a" => "verb" with similar frequency...
        "ai"    => "aux",
        "avoir" => "aux",      # or a verb

        # adjectives
        "son"   => "adj",      #ambig
        "sa"    => "adj",
        "ses"   => "adj",
        "cette" => "adj",      # na wiki je ako pronoun
        "mon"   => "adj",
        "ma"    => "adj",
        "deux"  => "adj",      # also as a numeral..?
        "tous"  => "adj",
        "ces"   => "adj",
        "mes"   => "adj",
        "cet"   => "adj",
        "notre" => "adj",
        "nos"   => "adj",
        "votre" => "adj",
        "vos"   => "adj",

        # articles
        "la"  => "art",        #ambig
        "le"  => "art",        #ambig
        "les" => "art",        #ambig
        "l'"  => "art",        #ambig
        "l"   => "art",        #ambig + to work around bad tokenization
        "un"  => "art",        #ambig
        "une" => "art",        #ambig
        "du"  => "art",        # contraction or an article
        "des" => "art",        # dtto with des

        #   "au"    => "art",       # this can be only contraction...
        #   "aux"   => "art",
        # najcastejsie zamena
        "m'"    => "pron",
        "t'"    => "pron",
        "ç'"   => "pron",
        "c'"    => "pron",
        "m"     => "pron",    # to work around bad tokenization
        "t"     => "pron",    # to work around bad tokenization
        "ç"    => "pron",    # to work around bad tokenization
        "c"     => "pron",    # to work around bad tokenization
        "que"   => "pron",
        "qu'"   => "pron",
        "qu"    => "pron",
        "il"    => "pron",
        "je"    => "pron",
        "j'"    => "pron",
        "j"     => "pron",
        "se"    => "pron",
        "qui"   => "pron",
        "vous"  => "pron",
        "elle"  => "pron",
        "ce"    => "pron",
        "on"    => "pron",
        "lui"   => "pron",
        "nous"  => "pron",
        "ils"   => "pron",
        "tout"  => "pron",    # "tout" => "adv" has similar frequency :/
        "y"     => "pron",
        "me"    => "pron",
        "tu"    => "pron",
        "moi"   => "pron",
        "leur"  => "pron",
        "où"   => "pron",
        "rien"  => "pron",
        "ça"   => "pron",
        "te"    => "pron",
        "toi"   => "pron",
        "celui" => "pron",
        "cela"  => "pron",
        "elles" => "pron",
        "eux"   => "pron",

        # autre - adj / pron 1:1
        #najcastejsie spojky
        "et"       => "conj",
        "mais"     => "conj",
        "comme"    => "conj",
        "ou"       => "conj",
        "quand"    => "conj",
        "puis"     => "conj",
        "ni"       => "conj",
        "car"      => "conj",    # alebo noun, menej casto
        "donc"     => "conj",
        "sinon"    => "conj",
        "pourquoi" => "conj",    # alebo adv, v pisanom castejsie spojka, v hovorenom naopak
        "comment"  => "conj",    # alebo adv, v pisanom castejsie spojka, v hovorenom naopak
        "si_conj"  => "conj",

        # najcastejsie predlozky
        "d'"      => "prep",
        "d"       => "prep",     # kvoli zlej tokenizacii
        "de"      => "prep",     #ambig
        "à"      => "prep",
        "en"      => "prep",     #   "en" => "pron",
        "dans"    => "prep",     #ambig
        "pour"    => "prep",
        "sur"     => "prep",
        "avec"    => "prep",
        "par"     => "prep",
        "sans"    => "prep",
        "sous"    => "prep",
        "vers"    => "prep",
        "entre"   => "prep",
        "après"  => "prep",
        "devant"  => "prep",
        "chez"    => "prep",
        "contre"  => "prep",
        "avant"   => "prep",
        "depuis"  => "prep",
        "pendant" => "prep",

        # najcastejsie adverbia
        "n'"         => "adv",
        "n"          => "adv",
        "pas"        => "adv",    #ambig
        "ne"         => "adv",
        "plus"       => "adv",    #ambig
        "bien"       => "adv",
        "tout"       => "adv",
        "encore"     => "adv",
        "aussi"      => "adv",
        "même"      => "adv",    # i adv
        "non"        => "adv",
        "jamais"     => "adv",
        "très"      => "adv",
        "toujours"   => "adv",
        "là"        => "adv",
        "alors"      => "adv",
        "si"         => "adv",    # skoro 1:1 conj/adverb, skusit nejaky system...
        "trop"       => "adv",
        "moins"      => "adv",
        "déjà"     => "adv",
        "oui"        => "adv",
        "peu"        => "adv",
        "maintenant" => "adv",
        "ici"        => "adv",
        "ainsi"      => "adv",
        "presque"    => "adv",
        "beaucoup"   => "adv",
        "enfin"      => "adv",

        # interpunction
        ","   => "interp",
        "."   => "interp",
        "..." => "interp",
        "!"   => "interp",
        "?"   => "interp",
        "\""  => "interp",
        "»"  => "interp",
        "«"  => "interp",
        ":"   => "interp",
        ";"   => "interp",
        "("   => "interp",
        ")"   => "interp",
        "{"   => "interp",
        "}"   => "interp",
        "["   => "interp",
        "]"   => "interp",
        "%"   => "interp",
        "&"   => "interp",
        "*"   => "interp",
        "-"   => "interp",
        "'"   => "interp",
    };
}

sub disamb_l_apostr {
    my ( $words_ref, $tags_ref ) = @_;

    # def art / pron
    for ( my $i = 0; $i < @{$words_ref} - 1; $i++ ) {
        my $current_word = $words_ref->[$i];
        my $current_tag  = $tags_ref->[$i];
        my $next_word    = $words_ref->[ $i + 1 ];
        my $next_tag     = $tags_ref->[ $i + 1 ];

        # if current word is la/le and next is verb, la/le is probably a pronoun, not an article/determiner
        if ( $current_word eq "la" || $current_word eq "le" || $current_word eq "l'" ) {
            if ( $next_tag eq "verb" ) {

                # print "changing la/le from art to pron\n";
                $tags_ref->[$i] = "pron";
            }
        }
    }
}

# these are most common ambiguous words in french (according to a paper I read) -> disambig would be useful
#  de, la, le, les, des, en, un, a, dans, une, pas, est, plus, son, si

sub disamb_s_apostr {
    my ($sentence) = @_;

    # conj / pron

    # conj si, in common_words
    $sentence =~ s/s' il/si_conj il/g;
    $sentence =~ s/s' ils/si_conj ils/g;

    # pron se, in common_words
    $sentence =~ s/s' /se /g;
    return $sentence;
}

sub expand_contractions {
    my ($sentence) = @_;

    # au -> à le_art
    $sentence =~ s/ au([ .\!?)«»,:;])/ à le$1/g;

    # aux -> à les_art
    $sentence =~ s/ aux([ .\!?)«»,:;])/ à les$1/g;

    return $sentence;
}

my %common_verb_suffixes = (
    "er"    => 1,
    "ir"    => 1,
    "e"     => 1,
    "es"    => 1,
    "ons"   => 1,
    "ez"    => 1,
    "ent"   => 1,
    "is"    => 1,
    "it"    => 1,
    "ai"    => 1,
    "as"    => 1,
    "a"     => 1,
    "îmes" => 1,
    "ins"   => 1,
    "int"   => 1,
    "ont"   => 1,
    "isse"  => 1,
);

sub verb_score {
    my ($word) = @_;
    my $score = 0;

    #most frq suffixes of most freq nouns (reversed)
    #
    foreach my $key ( keys %common_verb_suffixes ) {
        if ( $word =~ /$key$/ ) {
            $score = $common_verb_suffixes{$key};
            last;
        }
    }
    return $score;
}

# verbs:
# -er -ir
# indicatif present
# -e, -es, -e, -ons, -ez, -ent
# -is, -is, -it, -ons, -ez, -ent
# indicatif imparfait
# -ais, -ais, -ait, -ions, -iez, -aient
# -ois, -ois, -oit, -ions, -iez, -oient
# -ssais, -issais, -issait, -issions, -issiez, -issaient
# past historic
# -ai, -as, -a, -âmes, -âtes, -èrent
# -is, -is, -it, -îmes, -îtes, -irent
# -us, -us, -ut, -ûmes, -ûtes, -urent
# -ins, -ins, -int, -înmes, -întes, -inrent
# future
# -ai, -as, -a, -ons, -ez, -ont
# -erai, -eras, -era, -erons, -erez, -eront
# present cond
# -ais, -ais, -ait, -ions, -iez, -aient
# sobjonctif present
# e, -es, -e, -ions, -iez, -ent
# -isse, -isses, -isse, -issions, -issiez, -issent
# subjonctif imparfait
# -se, -ses, -ˆt, -sions, -siez, -sent
# -isse, -isses, -ît, -issions, -issiez, -issent

my %common_noun_4suffixes = (
    "sage"  => 13,
    "tage"  => 13,
    "ange"  => 13,
    "sure"  => 13,
    "rise"  => 13,
    "sier"  => 13,
    "neur"  => 13,
    "aces"  => 13,
    "udes"  => 13,
    "iles"  => 13,
    "oles"  => 13,
    "rmes"  => 13,
    "nnes"  => 13,
    "orts"  => 13,
    "nage"  => 14,
    "ante"  => 14,
    "otte"  => 14,
    "gnes"  => 14,
    "tons"  => 14,
    "tant"  => 14,
    "ieux"  => 14,
    "ande"  => 15,
    "iche"  => 15,
    "oche"  => 15,
    "isse"  => 15,
    "euse"  => 15,
    "cité" => 15,
    "sité" => 15,
    "nier"  => 15,
    "tier"  => 15,
    "bres"  => 15,
    "quet"  => 15,
    "able"  => 16,
    "dité" => 16,
    "rier"  => 16,
    "leur"  => 16,
    "nges"  => 16,
    "oirs"  => 16,
    "rage"  => 17,
    "deur"  => 17,
    "ndes"  => 17,
    "uche"  => 18,
    "asse"  => 18,
    "iste"  => 19,
    "llon"  => 19,
    "ison"  => 19,
    "ades"  => 19,
    "gues"  => 19,
    "seur"  => 20,
    "ites"  => 20,
    "ains"  => 20,
    "lons"  => 20,
    "lage"  => 21,
    "nité" => 21,
    "bles"  => 21,
    "tude"  => 22,
    "ente"  => 22,
    "ices"  => 22,
    "iens"  => 22,
    "ours"  => 22,
    "ntes"  => 23,
    "lets"  => 23,
    "stes"  => 24,
    "ules"  => 25,
    "sons"  => 26,
    "ises"  => 27,
    "lier"  => 28,
    "ries"  => 28,
    "rité" => 29,
    "aine"  => 30,
    "ards"  => 30,
    "oire"  => 33,
    "isme"  => 36,
    "tres"  => 36,
    "ités" => 36,
    "esse"  => 46,
    "elle"  => 51,
    "ture"  => 51,
    "ines"  => 51,
    "sses"  => 52,
    "erie"  => 54,
    "ères" => 54,
    "ires"  => 54,
    "ique"  => 55,
    "ants"  => 55,
    "ière" => 56,
    "nces"  => 57,
    "ages"  => 58,
    "ques"  => 59,
    "aire"  => 60,
    "ures"  => 60,
    "lité" => 62,
    "ches"  => 63,
    "eaux"  => 64,
    "ille"  => 72,
    "iers"  => 75,
    "teur"  => 78,
    "ttes"  => 78,
    "ence"  => 80,
    "sion"  => 81,
    "ette"  => 91,
    "ance"  => 96,
    "lles"  => 97,
    "ents"  => 109,
    "eurs"  => 127,
    "ions"  => 203,
    "ment"  => 246,
    "tion"  => 364,

    #   "esse"  => 46,
    #   ...
    #   "tion"  => 364,
    #   "ée"    => 400,
    #   "té"    => 400,
    #   "aine"  => 400,
    #   "ien"   => 400,
    #   "aise"  => 400,
    #   "ienne" => 400,
);

my %common_noun_3suffixes = (
    "ace"  => 17,
    "rge"  => 17,
    "mie"  => 17,
    "tie"  => 17,
    "rme"  => 17,
    "ume"  => 17,
    "ive"  => 17,
    "ile"  => 18,
    "nge"  => 19,
    "cle"  => 19,
    "ort"  => 19,
    "ute"  => 20,
    "ail"  => 20,
    "uet"  => 20,
    "vre"  => 21,
    "bes"  => 21,
    "nde"  => 22,
    "bre"  => 22,
    "ron"  => 22,
    "ale"  => 23,
    "ien"  => 23,
    "our"  => 23,
    "gne"  => 24,
    "ois"  => 24,
    "ans"  => 24,
    "ole"  => 25,
    "eté" => 25,
    "ais"  => 25,
    "use"  => 26,
    "ats"  => 26,
    "rts"  => 26,
    "ils"  => 27,
    "irs"  => 27,
    "ude"  => 28,
    "nne"  => 28,
    "ton"  => 28,
    "ite"  => 29,
    "ves"  => 29,
    "ble"  => 31,
    "gue"  => 31,
    "ain"  => 31,
    "lon"  => 31,
    "ots"  => 31,
    "ens"  => 32,
    "its"  => 33,
    "let"  => 33,
    "pes"  => 34,
    "son"  => 35,
    "oir"  => 35,
    "ice"  => 36,
    "rds"  => 36,
    "ste"  => 37,
    "eux"  => 37,
    "ule"  => 39,
    "ard"  => 41,
    "sme"  => 43,
    "ise"  => 47,
    "ées" => 49,
    "ade"  => 50,
    "nte"  => 50,
    "tés" => 53,
    "tre"  => 64,
    "ets"  => 68,
    "des"  => 70,
    "hes"  => 70,
    "rie"  => 73,
    "mes"  => 73,
    "ant"  => 76,
    "eau"  => 78,
    "ies"  => 80,
    "ins"  => 83,
    "che"  => 92,
    "aux"  => 94,
    "ues"  => 98,
    "sse"  => 100,
    "ère" => 101,
    "ges"  => 102,
    "ine"  => 105,
    "ure"  => 106,
    "ces"  => 106,
    "que"  => 107,
    "ire"  => 108,
    "age"  => 109,
    "ers"  => 111,
    "ses"  => 112,
    "tte"  => 113,
    "nes"  => 120,
    "ier"  => 124,
    "lle"  => 136,
    "urs"  => 151,
    "nts"  => 170,
    "nce"  => 180,
    "ité" => 189,
    "tes"  => 215,
    "eur"  => 219,
    "les"  => 221,
    "res"  => 277,
    "ent"  => 284,
    "ons"  => 324,
    "ion"  => 467,
);

sub noun_score {
    my ( $word, $suffix_length ) = @_;
    my $score = 0;

    #most frq suffixes of most freq nouns (reversed)

    my $noun_freq_suffix_ref;
    if ( $suffix_length == 3 ) {
        $noun_freq_suffix_ref = \%common_noun_3suffixes;
    }
    else {
        $noun_freq_suffix_ref = \%common_noun_4suffixes;
    }

    foreach my $key ( keys %{$noun_freq_suffix_ref} ) {
        if ( $word =~ /$key$/ ) {
            $score = $noun_freq_suffix_ref->{$key};
            last;
        }
    }
    return $score;
}

my %common_adj_4suffixes = (
    "érée" => 13,
    "onne"   => 13,
    "ctif"   => 13,
    "nnel"   => 13,
    "cées"  => 13,
    "hées"  => 13,
    "inés"  => 13,
    "nnés"  => 13,
    "sses"   => 13,
    "sifs"   => 13,
    "lent"   => 13,
    "taux"   => 13,
    "itée"  => 14,
    "aise"   => 14,
    "gées"  => 14,
    "mées"  => 14,
    "vées"  => 14,
    "ures"   => 14,
    "isés"  => 14,
    "nues"   => 14,
    "nels"   => 14,
    "endu"   => 14,
    "âtre"  => 15,
    "oise"   => 15,
    "ndue"   => 15,
    "sque"   => 15,
    "dues"   => 15,
    "qués"  => 15,
    "vant"   => 15,
    "arde"   => 16,
    "chée"  => 16,
    "cale"   => 16,
    "onné"  => 16,
    "ndus"   => 16,
    "inée"  => 17,
    "nnée"  => 17,
    "uées"  => 17,
    "chés"  => 17,
    "uels"   => 17,
    "uant"   => 17,
    "yant"   => 18,
    "ntée"  => 19,
    "ches"   => 19,
    "llés"  => 19,
    "teux"   => 19,
    "ette"   => 20,
    "ssés"  => 20,
    "llée"  => 21,
    "isée"  => 21,
    "quée"  => 21,
    "dant"   => 21,
    "illé"  => 22,
    "sive"   => 22,
    "oire"   => 23,
    "tres"   => 23,
    "nale"   => 24,
    "tale"   => 24,
    "iens"   => 24,
    "iant"   => 24,
    "atif"   => 25,
    "nées"  => 25,
    "iale"   => 26,
    "tifs"   => 26,
    "ssée"  => 27,
    "ueux"   => 27,
    "nnes"   => 28,
    "ains"   => 28,
    "neux"   => 28,
    "ième"  => 29,
    "ises"   => 29,
    "ites"   => 29,
    "rale"   => 30,
    "iles"   => 30,
    "iers"   => 30,
    "ides"   => 32,
    "tées"  => 33,
    "leux"   => 34,
    "aine"   => 35,
    "rées"  => 36,
    "iste"   => 37,
    "teur"   => 38,
    "ives"   => 38,
    "ères"  => 39,
    "stes"   => 39,
    "sées"  => 40,
    "rant"   => 40,
    "enne"   => 42,
    "eurs"   => 42,
    "lées"  => 43,
    "ière"  => 44,
    "ines"   => 44,
    "nant"   => 44,
    "reux"   => 44,
    "ents"   => 50,
    "lant"   => 56,
    "tant"   => 56,
    "ible"   => 58,
    "lles"   => 59,
    "tive"   => 60,
    "ieux"   => 61,
    "ente"   => 70,
    "elle"   => 77,
    "ales"   => 77,
    "sant"   => 92,
    "ires"   => 97,
    "aire"   => 120,
    "uses"   => 120,
    "bles"   => 168,
    "ants"   => 190,
    "ques"   => 207,
    "ntes"   => 217,
    "euse"   => 226,
    "able"   => 231,
    "ique"   => 278,
    "ante"   => 357,

    #   "sées"  => 40,
    #   ...
    #   "ante"  => 357,
);

my %common_adj_3suffixes = (
    "hée"  => 17,
    "hés"  => 17,
    "ndu"   => 17,
    "nde"   => 18,
    "cée"  => 18,
    "gés"  => 18,
    "vés"  => 18,
    "ris"   => 18,
    "iée"  => 19,
    "iné"  => 19,
    "nté"  => 19,
    "cés"  => 19,
    "nus"   => 19,
    "dée"  => 20,
    "éré" => 20,
    "rde"   => 21,
    "vée"  => 21,
    "nné"  => 21,
    "isé"  => 21,
    "nal"   => 21,
    "tal"   => 21,
    "nel"   => 21,
    "hes"   => 21,
    "més"  => 21,
    "due"   => 22,
    "nue"   => 22,
    "iés"  => 22,
    "uel"   => 23,
    "ces"   => 23,
    "dus"   => 23,
    "mée"  => 24,
    "ché"  => 24,
    "llé"  => 24,
    "ais"   => 24,
    "che"   => 25,
    "gée"  => 26,
    "its"   => 26,
    "ois"   => 27,
    "ens"   => 27,
    "ssé"  => 28,
    "tte"   => 28,
    "qué"  => 28,
    "sif"   => 28,
    "ral"   => 28,
    "sse"   => 29,
    "ués"  => 29,
    "ial"   => 30,
    "mes"   => 30,
    "ème"  => 31,
    "ain"   => 32,
    "ile"   => 36,
    "tre"   => 38,
    "ard"   => 39,
    "ide"   => 39,
    "ien"   => 39,
    "ers"   => 39,
    "ifs"   => 42,
    "ier"   => 43,
    "uée"  => 44,
    "ies"   => 45,
    "urs"   => 47,
    "els"   => 48,
    "tés"  => 49,
    "ise"   => 50,
    "ite"   => 50,
    "ins"   => 52,
    "ves"   => 54,
    "nés"  => 55,
    "sés"  => 55,
    "nne"   => 56,
    "ste"   => 57,
    "des"   => 60,
    "rés"  => 60,
    "ère"  => 62,
    "tif"   => 63,
    "née"  => 67,
    "lés"  => 68,
    "aux"   => 68,
    "sée"  => 72,
    "lée"  => 73,
    "ine"   => 73,
    "tée"  => 75,
    "eur"   => 76,
    "ent"   => 78,
    "rée"  => 81,
    "ive"   => 88,
    "lle"   => 92,
    "nes"   => 105,
    "ire"   => 144,
    "ale"   => 152,
    "ses"   => 183,
    "res"   => 211,
    "use"   => 232,
    "nts"   => 251,
    "eux"   => 267,
    "ues"   => 277,
    "ées"  => 298,
    "ble"   => 299,
    "que"   => 325,
    "les"   => 358,
    "tes"   => 358,
    "nte"   => 440,
    "ant"   => 452,
);
### POZOR! toto skore nevyjadruje nejaku frekvenciu, ktora by bola porovnatelna napr s frekvenciou pri substantivach :/
# tato frekvencia bola spocitana ako pocet vyskytov danej pripony medzi 10000 najcastejsie pouzivanymi adjektivami/substantivami
sub adj_score {
    my ( $word, $suffix_length ) = @_;
    my $score = 0;

    #most frq suffixes of most freq adjectives (reversed)

    my $adj_freq_suffix_ref;
    if ( $suffix_length == 3 ) {
        $adj_freq_suffix_ref = \%common_adj_3suffixes;
    }
    else {
        $adj_freq_suffix_ref = \%common_adj_4suffixes;
    }

    foreach my $key ( keys %{$adj_freq_suffix_ref} ) {
        if ( $word =~ /$key$/ ) {
            $score = $adj_freq_suffix_ref->{$key};
            last;
        }
    }
    return $score;
}

# if the sentence is a string, not an array of wordforms, this pre-editing can be useful
#   my ($sentence) = @_;
#   # sentence pre-editing
#
#   # conversion to one type of apostrophe
#   $sentence =~  s/’/'/g;
#
#   # spaces around interpunction
#   $sentence =~ s/([a-zA-ZàâéèêëîïôöùûüçÀÂÉÈÊËÎÏÔÖÙÛÜÇ0-9]+)([,!?.])/$1 $2/g;
#   $sentence =~ s/([\)\("«»\]\[:;]+)/ $1 /g;
#   $sentence =~ s/([']+)/$1 /g;
#   $sentence =~ s/-/ /g;
#
#   $sentence = disamb_s_apostr($sentence);
#   $sentence = expand_contractions($sentence);

#   my @words = split(/\s+/, $sentence);

1;

__END__

=head1 NAME

Treex::Tool::Tagger::Simple::FR - Perl module for POS tagging French

=head1 SYNOPSIS

  use Treex::Tool::Tagger::Simple::FR;
  my $tagger = Treex::Tool::Tagger::Simple::FR->new();
  my @words = qw(Alors la Sagesse changea de méthode et parla d'enquête et d'espionnage.);
  my ($tags_rf, $lemmas_rf) = $tagger->tag_and_lemmatize_sentence(@words);
  while (@words) {
      print shift @words, "\t", shift @{$lemmas_rf}, "\t", shift @{$tags_rf}, "\n";
  }

=head1 COPYRIGHT AND LICENCE

Copyright 2010-2011 Peter Fabian, Martin Popel

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
