package Treex::Block::W2W::Translit;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
# The following libraries are currently available in the old part of TectoMT.
use translit; # Dan's transliteration library
use translit::greek; # Dan's transliteration table for Greek script
use translit::cyril; # Dan's transliteration table for Cyrillic script
use translit::armen; # Dan's transliteration table for Armen script
use translit::urdu; # Dan's transliteration table for the Urdu (Arabic) script
use translit::brahmi; # Dan's transliteration tables for Brahmi-based scripts
use translit::tibetan; # Dan's transliteration table for Tibetan script
use translit::mkhedruli; # Dan's transliteration table for Georgian script
use translit::ethiopic; # Dan's transliteration table for Ethiopic (Amharic) script
use translit::khmer; # Dan's transliteration table for Khmer script

has 'table' => (isa => 'Hash', is => 'ro', default => {});
has 'maxl' => (isa => 'Int', is => 'rw', default => 1, writer => '_set_maxl');
has 'language' => (isa => 'Str', is => 'ro'); # source language code (optional)
has 'scientific' => (isa => 'Bool', is => 'rw', default => 1); # romanization type



#------------------------------------------------------------------------------
# Initializes the transliteration tables.
#------------------------------------------------------------------------------
sub BUILD
{
    my $self = shift;
    my $arg_ref = shift;
    my $table = $self->table();
    my $language = $self->language(); # optional source language code
    my $scientific = $self->scientific(); # type of romanization
    # 0x374: Greek script.
    translit::greek::inicializovat($table);
    # 0x400: Cyrillic.
    translit::cyril::inicializovat($table, $language);
    # 0x500: Armenian script.
    translit::armen::inicializovat($table);
    # 0x600: Arab script for Urdu.
    translit::urdu::inicializovat($table);
    # 0x900: Devanagari script (Hindi etc.)
    translit::brahmi::inicializovat($table, 2304, $scientific);
    # 0x980: Bengali script.
    translit::brahmi::inicializovat($table, 2432, $scientific);
    # 0xA00: Gurmukhi script (for Punjabi).
    translit::brahmi::inicializovat($table, 2560, $scientific);
    # 0xA80: Gujarati script.
    translit::brahmi::inicializovat($table, 2688, $scientific);
    # 0xB00: Oriya script.
    translit::brahmi::inicializovat($table, 2816, $scientific);
    # 0xB80: Tamil script.
    translit::brahmi::inicializovat($table, 2944, $scientific);
    # 0xC00: Telugu script.
    translit::brahmi::inicializovat($table, 3072, $scientific);
    # 0xC80: Kannada script.
    translit::brahmi::inicializovat($table, 3200, $scientific);
    # 0xD00: Malayalam script.
    translit::brahmi::inicializovat($table, 3328, $scientific);
    # 0xF00: Tibetan script.
    translit::tibetan::inicializovat($table);
    # 0x10A0: Georgian script.
    translit::mkhedruli::inicializovat($table);
    # 0x1200: Ethiopic script (for Amhar etc.)
    translit::ethiopic::inicializovat($table);
    # 0x1780: Khmer script.
    translit::khmer::inicializovat($table);
    # Figure out and return the maximum length of an input sequence.
    my $maxl = 1; map {$maxl = max($maxl, length($_))} (keys(%{$table}));
    $self->_set_maxl($maxl);
}



#------------------------------------------------------------------------------
# Transliterates the word form of one node (token).
#------------------------------------------------------------------------------
sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $form = $node->form();
    my $translit;
    if(defined($form))
    {
        my $table = $self->table();
        my $maxl = $self->maxl();
        $translit = translit::prevest($table, $form, $maxl);
    }
    $node->set_attr('translit', $translit);
}



#------------------------------------------------------------------------------
# Returns maximum of two values.
#------------------------------------------------------------------------------
sub max
{
    my $a = shift;
    my $b = shift;
    return $a>=$b ? $a : $b;
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2W::Translit

=head1 DESCRIPTION

Transliterates the C<form> attribute of each node and puts the result in the C<translit> attribute.
Note that there may be other attributes (especially C<lemma>) that could be transliterated but
this block ignores them.

By default the transliteration goes from a non-Latin to the Latin script, i.e.
we perform I<romanization>. Other transliteration directions could be activated by replacing the
transliteration tables.

Pure I<transliteration> (as opposed to I<transcription>) scheme would mean that there is
a 1-1 mapping between the source and the target alphabets, thus making the process reversible.
Our transliteration tables do not follow this principle strictly.

The block can be applied to any text in a language-independent fashion.
If the script is supported, all non-Latin characters will be romanized.
However, it is sometimes desirable to adjust the transliteration tables to a particular source
language, reflecting its pronunciation. For instance, the cyrillic letter I<Г>
should be rewritten as I<G> if the source language is Russian,
and as I<H> if the source language is Ukrainian.
So the block is able to take the language of the current zone into account, wherever applicable.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008 – 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
