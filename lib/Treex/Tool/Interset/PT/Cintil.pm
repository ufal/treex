package Treex::Tool::Interset::PT::Cintil;
use utf8;
use Moose;
with 'Treex::Tool::Interset::Driver';

# See http://cintil.ul.pt/cintilwhatsin.html#guidelines and
# https://wiki.ufal.ms.mff.cuni.cz/user:zeman:interset:features
my $DECODING_TABLE = {
    ADJ     => { pos => 'adj' }, # Adjectives
    ADV     => { pos => 'adv' }, # Adverbs
    CARD    => { pos => 'num',  numtype => 'card' }, #  Cardinal s
    CJ      => { pos => 'conj'}, # Conjunctions "e", "que", "como"
    CL      => { pos => 'part', other => 'clitic' }, #  Clitic s
    CN      => { pos => 'noun'}, # Common Nouns
    DA      => { pos => 'adj',  adjtype => 'art', definiteness=> 'def'}, # Definite Articles
    DEM     => { pos => 'noun', prontype => 'dem' }, # Demonstrative s
    DFR     => { pos => 'num', numtype => 'frac' }, # Denominators of Fraction
    DGTR    => { pos => 'num', numform => 'roman'}, # Roman Numerals
    DGT     => { pos => 'num', numform => 'digit'}, # Digits
    DM      => { pos => 'int'}, # Disourse Marker "olá"
    EADR    => { pos => 'noun', other => 'url'}, # Electronic Addresses
    EOE     => { pos => 'part', abbr => 'abbr'}, # End of Enumeration  etc
    EXC     => { pos => 'int'}, # Exclamation ah, ei, …
    GER     => { pos => 'verb', verbform => 'part'}, # Gerunds sendo, afirmando, vivendo, …
    GERAUX  => { pos => 'verb', verbform => 'part', verbtype => 'aux'}, # Gerund "ter"/"haver" in compound tenses tendo, havendo
    IA      => { pos => 'adj', adjtype => 'art', definiteness => 'ind'}, # Indefinite Articles uns, umas, …
    IND     => { pos => 'noun', prontype => [qw(ind neg tot)]}, # Indefinites tudo, alguém, ninguém, …
    INF     => { pos => 'verb', verbform => 'inf'}, # Infinitive  ser, afirmar, viver, …
    INFAUX  => { pos => 'verb', verbform => 'inf'}, # Infinitive "ter"/"haver" in compound tenses ter, haver, …
    INT     => { pos => [qw(noun adv)], prontype => 'int'}, # Interrogatives  quem, como, quando, …
    ITJ     => { pos => 'int'}, # Interjection    bolas, caramba, …
    LTR     => { pos => 'punc', punctype => 'symb', other => 'letter'}, # Letters a, b, c, …
    MGT     => { pos => 'num', numform => 'word'}, # Magnitude Classes   unidade, dezena, dúzia, resma, …
    MTH     => { pos => 'noun'}, # Months  Janeiro, Dezembro, …
    NP      => { pos => 'noun', abbr => 'abbr'}, # Noun Phrases    idem, …
    ORD     => { pos => 'num',  numtype => 'ord'}, # Ordinals    primeiro, centésimo, penúltimo, …
    PADR    => { pos => 'noun'}, # Part of Address Rua, av., rot., …
    PNM     => { pos => 'noun', nountype => 'prop'}, # Part of Name    Lisboa, António, João, …
    PNT     => { pos => 'punc'}, # Punctuation Marks   ., ?, (, …
    POSS    => { pos => 'adj', prontype => 'prs', poss => 'poss'}, # Possessives meu, teu, seu, …
    PPA     => { pos => 'verb', verbform => 'part', tense => 'past'}, # Past Participles not in compound tenses sido, afirmados, vivida, …
    PP      => { pos => 'adv'}, # Prepositional Phrases   algures, …
    PPT     => { pos => 'verb', verbform => 'part', tense => 'past'}, # Past Participle in compound tenses  sido, afirmado, vivido, …
    PREP    => { pos => 'adp'}, # Prepositions    de, para, em redor de, …
    PRS     => { pos => 'noun', prontype => 'prs'}, # Personals   eu, tu, ele, …
    QNT     => { pos => 'adv', advtype => 'deg'}, # Quantifiers todos, muitos, nenhum, …
    REL     => { pos => 'noun', prontype => 'rel'}, # Relatives   que, cujo, tal que, …
    STT     => { pos => 'noun', abbr => 'abbr'}, # Social Titles   Presidente, drª., prof., …
    SYB     => { pos => 'punc', punctype => 'symb'}, # Symbols @, #, &, …
    TERMN   => { pos => ''}, # Optional Terminations   (s), (as), …
    UM      => { pos => 'adj', adjtype => 'art', definiteness => 'ind', numvalue => '1'}, # "um" or "uma"
    UNIT    => { pos => 'noun', abbr => 'abbr'}, # Abbreviated Measurement Unit    kg., km., …
    VAUX    => { pos => 'verb', verbtype => 'aux'}, # Finite "ter" or "haver" in compound tenses  temos, haveriam, …
    V       => { pos => 'verb'}, # Verbs (other than PPA, PPT, INF or GER) falou, falaria, …
    WD      => { pos => 'noun'}, # Week Days   segunda, terça-feira, sábado, …

    # Tags for nominal categories
    'm'     => { gender => 'masc' }, # Masculine
    f       => { gender => 'fem' }, # Feminine
    's'     => { number => 'sing' }, # Singular
    p       => { number => 'plu' }, # Plural
    dim     => { other  => 'diminutive' }, # Diminutive
    sup     => { degree => 'sup' }, # Superlative
    comp    => { degree => 'comp' }, # Comparative
    # Tags for verbs
    1       => { person => '1' }, # First Person
    2       => { person => '2' }, # Second Person
    3       => { person => '3' }, # Third Person
    pi      => { tense => 'pres', mood => 'ind' }, # Presente do Indicativo
    ppi     => { tense => 'past', aspect => 'perf', mood => 'ind' }, # Pretérito Perfeito do Indicativo
    ii      => { tense => 'imp', mood => 'ind'}, # Pretérito Imperfeito do Indicativo
    mpi     => { tense => 'pqp', mood => 'ind'}, # Pretérito Mais que Perfeito do Indicativo
    fi      => { tense => 'fut', mood => 'ind'}, # Futuro do Indicativo
    c       => { mood => 'cond' }, # Condicional
    pc      => { tense => 'pres', mood => 'sub'}, # Presente do Conjuntivo
    ic      => { tense => 'imp', mood => 'sub'}, # Pretérito Imperfeito do Conjuntivo
    fc      => { tense => 'fut', mood => 'sub'}, # Futuro do Conjuntivo
    imp     => { mood => 'imp'}, # Imperativo
    # Tags for infinitive verbs
    ifl     => { }, # Inflected
    nifl    => { }, # Not Inflected
    # Not in guidelines
    inf     => { verbform => 'inf'}, # probably infinitive
    ninf    => { }, # probably the same as "nifl"
    nInf    => { }, # probably the same as "nifl"
    g       => { }, # probably undetermined gender
    n       => { }, # probably undetermined number
};

sub split_tag {
    my ($self, $tag) = @_;
    my ($pos, $feats) = split /#/, $tag;
    
    # multiword conjunctions: LCJ1, LCJ2, LCJ3 -> CJ
    # multiword adverbs: LADV1, LADV2 -> ADV
    # and so on for eight more PoS tags
    $pos =~ s/L(.+)\d/$1/;
    
    # Categories (e.g. "pi-3s") are joined by hyphens.
    # We also want to split numbers (indicators of person) from the rest.
    # Moreover we want to split gender (m,f,g) and number (s,p,n).
    # g is an undocumented gender (used mostly with numerals).
    # n is an undocumented number (used mostly with enclitic "se").
    my @categories = map {/^([mfg])([spn])$/ ? ($1, $2) : $_} grep {/[^_-]/} split /(-|\d)/, $feats;
    
    return ($pos, @categories);
}

sub decoding_table {
    return $DECODING_TABLE;
}

1;

__END__

=head1 NAME

Treex::Tool::Interset:PT::Cintil - morphological tagset of the (Portuguese) CINTIL corpus

=head1 SYNOPSIS

 use Treex::Tool::Interset::PT::Cintil;
 my $driver = Treex::Tool::Interset::PT::Cintil->new();
 my $iset = $driver->decode('V#pi-3s');
 # $iset = { pos=>'verb', tense=>'pres', mood=>'ind', person=>'3', number=>'sing', tagset => 'PT::Cintil' };
 my $tag = $driver->encode({ pos => 'adj',  adjtype => 'art' });

=head1 DESCRIPTION

Conversion between Portuguese CINTIL tagset and Interset (universal tagset by Dan Zeman).

=head1 SEE ALSO

L<http://cintil.ul.pt/cintilwhatsin.html#guidelines>

L<Treex::Tool::Interset::Driver>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
