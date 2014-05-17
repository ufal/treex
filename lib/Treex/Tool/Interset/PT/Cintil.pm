package Treex::Tool::Interset::PT::Cintil;
use utf8;
use Moose;
with 'Treex::Tool::Interset::Driver';

# See https://wiki.ufal.ms.mff.cuni.cz/user:zeman:interset:features
my $DECODING_TABLE = {
    # Tags defined in the guidelines CINTILDependencyBankHandbook_v7.pdf
    A       => { pos => 'adj' }, # Adjective
    ADV     => { pos => 'adv' }, # Adverb
    ART     => { pos => 'adj',  subpos => 'art' }, #    Article 
    C       => { pos => 'conj', subpos => 'sub' }, # Complementizer  ??? other => 'complementizer'
    CARD    => { pos => 'num',  numtype => 'card' }, #  Cardinal 
    CL      => { pos => 'part' }, #  Clitic 
    CONJ    => { pos => 'conj' }, #  Conjunction  # ??? subpos => 'coord',
    D       => { pos => 'adj',  subpos => 'det' }, #   Determiner 
    DEM     => { pos => 'noun', prontype => 'dem' }, # Demonstrative 
    ITJ     => { pos => 'int' }, #  Interjection 
    N       => { pos => 'noun' }, # Noun 
    ORD     => { pos => 'num',  numtype => 'ord' }, #  Ordinal 
    P       => { pos => 'prep' }, # Preposition 
    PERCENT => { pos => 'num' }, # Percentage : "cento"
    PNT     => { pos => 'punc' }, # Punctuation 
    POSS    => { pos => 'adj',  prontype => 'prs', poss => 'poss' }, #  Possessive : "sua", "seu", "nossos", "meus", ...
    PRS     => { pos => 'noun', prontype => 'prs' }, #  Personal  pronoun 
    QNT     => { pos => 'adv',  advtype => 'deg' }, # Quantifier : "todos", "imensas", ...
    REL     => { pos => 'noun', prontype => 'rel' }, #  Relative  pronoun : "que", "quem", ...

    # Most frequent tags found in depbank-v3v4.conll (and undefined by the guidelines)
    CN      => { pos => 'noun'},
    PREP    => { pos => 'prep'},
    DA      => { pos => 'adj',  subpos => 'art'}, # or subpos => 'det' ? : "o", "a"
    V       => { pos => 'verb'},
    PNM     => { pos => 'noun', subpos => 'prop'}, # "Manuel"
    CJ      => { pos => 'prep'}, # "que", "como"
    UM      => { pos => 'adj', subpos => 'art', definitness => 'ind'}, # "um"
    PPA     => { pos => 'adj'},
    DGT     => { pos => 'num', numform => 'digit'},   
};

sub decoding_table {
    return $DECODING_TABLE;
}

1;

__END__

=head1 NAME

Treex::Tool::Interset::Driver - morphological tagset of the (Portuguese) CINTIL  DepBank

=head1 SYNOPSIS

=head1 DESCRIPTION



=head1 METHODS

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
