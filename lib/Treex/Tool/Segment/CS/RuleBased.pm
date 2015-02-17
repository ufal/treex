package Treex::Tool::Segment::CS::RuleBased;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Tool::Segment::RuleBased';

# Note, that we cannot write
# sub get_unbreakers { return qr{...}; }
# because we want the regex to be compiled just once, not on every method call.
my $UNBREAKERS = qr{\p{Upper}|fr|vl|ch| # first name abbrevs.
    pí?|f[ay]|mr|mr?s|tr|               # "pan", "paní", "firma", "trenér"
    ing|arch|                           # academic titles
    (ph|rn|paed?|ju|mu|mv|md|rs|rc|rt|th|ic|pharm)dr|
    prof|doc|mgr|bc|mag|ph|bca|mga|ph|
    sv|                                 # "svatý"
    st|čes|uh|čs|                       # "St. Tropez", "Uh. Hradiště", "Čes. Třebová", "Čs. republika"
    gen|p?plk|[np]?por|š?kpt|mjr|sgt|   # military titles
    např|srov|tzv|mj|zn|tj|resp|popř|   # listing, references
    a\.d|                               # foreign "an der"
    sev|již|záp|vých|                   # "Severní Irsko", "Jižní Karolína"
    k\.\h*ú                             # katastrální území
}xi;

override unbreakers => sub {
    return $UNBREAKERS;
};

# Characters that can appear after period (or other end-sentence symbol)
sub closings {
    return '"”“‘»);';    # Czech closing punctuation
}

# Characters that can appear before the first word of a sentence
sub openings {
    return '"“„‚«(';     # Czech opening punctuation
}

# Context with which a person or company name should not end
my $NON_NAME_END = qr{
    (?:^|                                               # paragraph start
    [\n\.\(\[\)\]"“„])[^\p{Upper}]*|                    # line start, punctuation + no capital letter
    ,[^\p{Upper}]+\s+|                                  # comma + at least one non-capitalized word
    (?:[^\p{Upper}]+\b\s*){4,}|                         # at least 4 non-capitalized words
    \b(?:                                               # common words that do not end person/company names
        k|v|podle|bez|s|u|o|do|za|přes|vedle|mimo|
        a|také|i|zejména|vyjma|bez|z|
        jelikož|protože|neboť|když|poněvadž|
        kdyby|aby|by|se|bude|je|budou|jsou|byl[ayi]?|má|mají|měl[aiy]?|musí|mít|musel[ayi]?|muset
    )\s+
}xi;

# Context with which a person or company name should not begin
my $NON_NAME_BEG = '(?:\s*\b.+){,4}(\.|$)';

# Indication of a cardinal numeral, even with a dot behind it
my $CARDINAL_INDIC = qr{
    \b(
        (tel|fax|č|č\.\h*p|str|čís|čl|odst)\.|                         # abbreviations indicating cardinal number
        čísl.{1,2}|str[aá]n.{1,4}|                                     # words indicating cardinal number
        (l[ée]t|ro[kc]|jar|podzim|zim).{0,3}|                          # time periods
        (lede?n|únor|březe?n|dube?n|květe?n|červe?n|červene?c|srpe?n|září|říje?n|listopad|prosine?c).{0,2}|
        [0-9]+\h*[\)\:\.]?|                                            # numbers 1000+/phone, football (1:0), dates: 1.1.2001 
        praha|ostrava|olomouc|pardubice|brno|budějovice|plzeň|králové| # "Praha 1"
        než|také|rovněž|z                                              # comparatives
    )\h*
    |[-'`´]                                                            # unary minus, years ('91) (no spaces)
}xi;

# Various monetary unit names (to be used in an ingore-case context)
my $MONETARY = 'kč|sk|us|dm|\p{Upper}{3}|mare?k.{0,3}|dolar.{0,3}|libe?r.{0,3}|euro?';

# NB: Consider well the usage of \h (horizontal whitespace) instead of \s in regexes.
sub apply_contextual_rules {
    my ( $self, $text ) = @_;

    # clear space before dots for given names and big numbers
    $text =~ s/\b(\p{Upper}|[bm]il|mld|tis)\h+\./$1./g;

    # arabic/roman numeral/"př." at the very beginning of a sentence
    $text =~ s/(^|\n\h*)([0-9\.]+|[IVXLCMD]+|P[Řř])\.(\h*)/$1$2<<<DOT>>>$3/g;

    # law captions
    $text =~ s/(^|\n\h*)(zákon|vyhláška|nařízení)(\s*)(č)\.(\s*[0-9]+\s*\/\s*[0-9]+\s*Sb)\./$1$2$3$4<<<DOT>>>$5<<<DOT>>>/gi;

    # hl. m. Praha
    $text =~ s/hl\.(\s*)m\.(\s*)(Prah)/hl<<<DOT>>>$1m<<<DOT>>>$2$3/gi;

    # ml., st. Boleslav
    $text =~ s/(ml|st)\.(\s*Boleslav)/$1<<<DOT>>>$2/gi;

    # Kat. B
    $text =~ s/(kat)\.(\s*(\p{Upper}|[0-9]|[IVX]+))\b/$1<<<DOT>>>$2/gi;

    # ordinal numerals
    my $numeral = '[0-9]{1,3}|\b[IVXLC]+';

    while ( $text =~ m/($numeral)\./gi ) {

        my ( $num, $precontext ) = _get_context( $text, ( pos $text ), $1 );

        if ( $precontext !~ m/(?:$CARDINAL_INDIC)$/i ) {
            my $pos = pos $text;
            $text = _unbreak_at( $text, ( pos $text ) );
            # pos($text) must be set here as $text is re-initialized on previous line,
            # which resets pos $text to 0 on some architectures (noticed on Ubuntu in Hyper-V)
            pos($text) = $pos;
        }
    }

    # big numbers and monetary units
    $text =~ s/([bm]il|mld|tis)\.(\s*)($MONETARY)\b/$1<<<DOT>>>$2$3/gi;

    # river names
    $text =~ s/\b(n)\.(\s*(\p{Upper}\.|Labem|Nisou|Odrou|Vlt\.|Vltavou|Rýnem|Mohanem|Dyjí))/$1<<<DOT>>>$2/gi;

    # a.s., Ph.D., Dr., spol. s r. o., s. p., n. p. -- only in "non-name" context
    my $name_abbrev = 'a\.\s*s|(?:spol(?:ečnost.{0,3}|\.)\s+)?s\.?\s*r\.\s*o|o\.\s*z|dr|ph\.\s*d|[sn]\.\s*p';

    while ( $text =~ m/\b($name_abbrev)\./gi ) {

        my ( $abbrev, $precontext, $postcontext ) = _get_context( $text, ( pos $text ), $1 );

        if ( $abbrev eq 'dr' || $precontext =~ m/($NON_NAME_END)$/ || $postcontext =~ m/^($NON_NAME_BEG)/ ) {
            $text = _unbreak_at( $text, ( pos $text ) );
        }
    }

    # royal names with adjectival attributes: "Ludvík II. Bavorský"
    $text =~ s/\b(\p{Upper}\p{Lower}+\s+[IVX]+)\.(\s+\p{Upper}\p{Lower}+(ý|ého|ému|ém|ým))\b/$1<<<DOT>>>$2/g;

    # str. III., čl. II.
    $text =~ s/\b(str|čl|č)\.(\s*[IVXLCMD]+)/$1<<<DOT>>>$2/g;

    # no break for 3 words in a parenthesis at most, if there's no capital letter after the parenthesis
    $text =~ s/\.(\s*[\(\[](?:\s*\b\S+){1,3}[\)\]]\s*\P{Upper})/<<<DOT>>>$1/g;
    
    # ul., tř., blvd., av., ave., nám. (after uncapitalized or capitalized abbreviation; "nám" collides with dative of "my"/"we" -- stricter)
    $text =~ s/((?:\p{Punct}|\b\p{Upper}{2,}|metro|na)\s*)(nám)\.(\s*\P{Upper})/$1$2<<<DOT>>>$3/;
    $text =~ s/((?:\b\p{Lower}+|\p{Punct}|\b\p{Upper}{2,})\s*)(ul|tř|blvd|av|ave)\.(\s*\P{Upper})/$1$2<<<DOT>>>$3/;
    
    # use spaced '-' and '*' as segment breaks between sentences (used in dialogs) 
    # TODO -- make this a list type (!)
    $text =~ s/([!?]|\w{4,}\.)\h+([\*\-–]\h+\p{Upper})/$1\n$2/g;       

    return $text;
}

# Returns the matching position and the previous and following context of up to 100 characters
sub _get_context {

    my ( $text, $pos, $abbrev ) = @_;

    my $rpos        = $pos - length($abbrev) - 1;
    my $precontext  = substr( $text, List::Util::max( $rpos - 100, 0 ), List::Util::min( 100, $rpos ) );
    my $postcontext = substr( $text, $pos, 100 );

    return ( $abbrev, $precontext, $postcontext );
}

# Inserts <<<DOT>>> instead of '.' at the given position
sub _unbreak_at {
    my ( $text, $pos ) = @_;

    $text = substr( $text, 0, $pos - 1 ) . '<<<DOT>>>' . substr( $text, $pos );
    return $text;
}

my $DAYS_OF_WEEK = qr{
    pondělí|úterý|středa|čtvrtek|pátek|sobota|neděle|
    po|út|st|čt|pá|so|ne
}xi;

my $TV_CHANNELS = qr{
    čt[1234](?: sport)?|čt24|nova(?: cinema| sport)?|prima(?: cool| love)?|premiéra|čtv|
    f1|ok3|hbo|stv[12]|markíza|joj(?: plus)?|barrandov|óčko|public tv|(?:tv )?noe|
    mdr|ndr|3sat|ard|br(?:-alpha)?|(?:super[ -])?rtl2?|zdf|wdr|orf[12]|
    bbc|cnn|eurosport|euronews
}xi;

my $MONTHS = qr{
    lede?na?|února?|březe?na?|dube?na?|květe?na?|červe?na?|
    červene?ce?|srpe?na?|září|říje?na?|listopadu?|prosine?ce?    
}xi;

my $SPORTS = qr{
    konečné|celkové|průběžné|absolutní|výsledky|pořadí|stav|tabulka|přehled|
    velká\h+cena|ms|me|sp|(?:mezinárodní\h+)?mistrovství|
    (?:(?:první|druhý|třetí|čtvrtý)\h+)?závod|k1|c1|grand\h+prix|   
    finále|semifinále|čtvrtfinále|skupina|kategorie|odveta|kvalifikace|
    (?:třída\h+)?do\h+[0-9]+\h+ccm|superbik\w*|supersport\w*|rallye|
    muži|ženy|marat[oó]n\w*|volejbal|basketbal|halové|
    počet\h+startů|brankáři|útočníci|obránci|záložníci|
    lyžování|slalom|sjezd\w*|skoky|biatlon|atletika|fotbal|motorismus|formule|
    (?:stolní\h+)?tenis|atletika|(?:pozemní\h+)?hokej|střelba|házená|veslování|krasobruslení|
    disk|oštěp|koule|běh|plavání|kladivo|tyč|dálka|výška|štafeta|trojskok|
    (?:(?:10|5)\h+)?[0-9]{1,2}0{1,2}\h+m(?:etrů)?\b|míle|
    (?:okresní\h+|oblastní\h+|krajský\h+)?přebor|extraliga|liga
}xi;

my $SPORT_NUMBERED = qr{
    kolo|místo|liga|jízda|rozběh
}xi;

# Czech list types
my $LIST_TYPES = [
    {   name => 'Elections -- Volební obvod č. XY',
        sep  => 'Volební\h+(?:obvod|okrsek)\h+č.\h*[0-9]+',
        type => 's',
    },
    {   name => 'Sport -- 1. kolo, 1. místo, disk:, oštěp:, tabulka po...',
        sep  => '\b(?:(?:[0-9]+|[IVXLC]+)\h*[a-h]?\.\h*(?:' . $SPORT_NUMBERED . ')'
            . '|(?:' . $SPORTS . ')(?:[\h\.,<>]+\w+){0,8}\.?)\h*[-–—:\(]',
        neg_pre => '(?:(?:-\h*|^)[0-9]+\h*[\+\.]|[0-9]+[\.:][0-9]+|\b(?:ve?|až|'. $SPORTS .')[\h,]?|[-–—:])\h*',
        type    => 's',
    },
    {   name => 'Sport -- Sparta - Slavia 1:2 (...)',
        sep  => '\b\h*\p{Upper}(?:[\p{Alnum}\.\']+\h+){0,5}\h*(?:\((?:\h*[\p{Alnum}\.\'–—-]+\h+){0,3}[\p{Alnum}\.\'–—-]+\h*\))?\h*'
            . '[-–—]\h*\p{Upper}(?:[\p{Alnum}\.\']+\h+){0,5}\h*(?:\((?:\h*[\p{Alnum}\.\'–—-]+\h+){0,3}[\p{Alnum}\.\'–—-]+\h*\))?\h*'
            . '[0-9]{1,3}:[0-9]{1,3}',
        type => 's',
    },
    {   name => 'Date/Time in parentheses -- cultural programs',
        sep  => '(?:[0-9]{1,2}\h*[\.:]\h*(?:[0-9]{1,2}\.?|' . $MONTHS . ')\h*[-–—]\h*)?'
            . '[0-9]{1,2}\h*[\.:]\h*(?:[0-9]{1,2}\.?|' . $MONTHS . ')\)[,\.;]?',
        type => 'e',
    },
    {    # possibly should be merged with the previous one
        name => 'Cinema programs -- "Begins at"',
        sep  => 'zač(?:\.|íná|átek)(?:\h*[\(\)/–—+-]?\h*(?:[0-9]{1,2}(?:\h*[:\.])?|h(?:od\.|odin)?|'
            . $DAYS_OF_WEEK . '|ve?|mimo|kromě|také|též|[ai,]))+\b(?:\h*[\(\)/])?',
        type => 'e',
    },
    {   name => 'TV/Cinema programs -- Date/time (range)',
        sep  => '\b(?:(?:' . $TV_CHANNELS . ')\h*)?(?:(?:' . $DAYS_OF_WEEK . ')\h*)?'
            . '(?:(?:[0-9]{1,2}\h*[\.:]\h*)?[0-9]{1,2}\.?\h*[-–—]\h*)?[0-9]{1,2}\h*[\.:]\h*[0-9]{1,2}'
            . '\b(?!\h*(?:[,:]?\h*[0-9]|h(?:\.?|od\.?|odin)\b\h*(?:[^:]|$)|min(?:\.|ut)))',
        type    => 's',
        neg_pre => '(?:(?:[\(:]|\b[0-9]+\h*,?|od)\h*)',
        min => 20, # Some TV program names are very short
    },
    {   name => 'Product lists -- Typ: XY',
        sep  => 'typ:',
        type => 's',
    },
    {   name    => 'Generic lists -- (a), (b), c), 4b), 4 a), 1. a)',
        sel_sep => '\b\(?(\h*[0-9]+\.?)?\h*(?!(?:kg|ks|l|h|lb)\b)[a-z]{1,2}\h*\)\h+',    # kg, ks, l, h left out
        sep     => '\b\(?(\h*[0-9]+\.?)?\h*[a-z]{1,2}\h*\)\h+',
        type    => 's',
    },
    {   name => 'Generic lists -- (1.1.1), (1), 1)',
        sep  => '\(?\h*\b[0-9]{1,3}(\.[0-9]{1,3})*\.?\h*\)\h+',
        type => 's',
    },
    {   name => 'Generic lists -- 1.1., 1.1, 1. 2. 3.',
        sep  => '\b(?:[0-9]{1,3}\h*\.(?:\h*[0-9]{1,3}\h*\.?)*\h*[-–—]\h*)?[0-9]{1,3}\h*\.(?:\h*[0-9]{1,3}\h*\.?)*'
            . '(?!\h*(?:' . $MONTHS . '|ročníku))', # dates excluded (TODO check if this is sane)
        type    => 's',
        neg_pre => '(?:[\(:]\h*|[0-9]+\h*(?:[-–—,.]\h*)?|\b(?:od|do|o|před|dn[ei]|ke?|po|ve?)\h+)',
        sel_sep => '\b(?:[0-9]{1,3}\h*\.(?:\h*[0-9]{1,3}\h*\.?)*\h*[-–—]\h*)?[0-9]{1,3}\h*\.(?:\h*[0-9]{1,3}\h*\.?)*'
            . '(?!\h*(?:' . $MONTHS . '|kolo|závod|ročníku))', # "kolo" excluded from selection
        min     => 40, # too short list items are quite suspicious
    },
];

override 'list_types' => sub {
    my ($self) = @_;

    # add Czech-specific list types after the universal ones (i.e. semicolon lists)
    return $self->SUPER::list_types, @{$LIST_TYPES};
};

override 'split_at_any_punctuation' => sub {
    my ( $self, $text ) = @_;

    $text =~ s/([a-z]\s*)-(\s*li\b)/$1<<<DASH>>>$2/g;

    return map { $_ =~ s/<<<DASH>>>/-/g; $_ } $self->SUPER::split_at_any_punctuation($text);
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Segment::CS::RuleBased

=head1 DESCRIPTION

Sentence boundaries are detected based on a regex rules
that detect end-sentence punctuation ([.?!]) followed by a uppercase letter.

This class adds a Czech specific list of "unbreakers",
i.e. tokens that usually do not end a sentence
even if they are followed by a period and a capital letter, and
a Czech-specific list of contextual rules, such as handling of ordinal numbers
or various abbreviations that apply in specific contexts only.

=head1 TODO

Known shortcomings:

Segmenting too much at:

  Za a). Bla bla bla
  kap. <chapter name>
  vš. SKP Plzeň (what's that?)
  three dots in parentheses, at the beginning of a sentence
  "min." in parentheses  

Not segmenting at:

  abbreviations like S.P.Z., S.M.A.R.T. at the end of sentence
  Ph. D. at the end of sentence
  units of measure, such as 220, 380 V, 10 A at the end of the sentence

=head1 SEE ALSO

L<Treex::Block::W2A::Segment>

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
