package Treex::Block::W2W::Deromajize;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
# The following libraries are currently available in the old part of TectoMT.
use translit; # Dan's transliteration library
use translit::deromajize; # Rudolf's transliteration table for Romaji -> Japanese

has 'table' => (isa => 'HashRef', is => 'ro', default => sub {{}});
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
    # Romaji script.
    translit::deromajize::inicializovat($table);
    # Figure out and return the maximum length of an input sequence.
    my $maxl = 1; map {$maxl = max2($maxl, length($_))} (keys(%{$table}));
    $self->_set_maxl($maxl);
}



#------------------------------------------------------------------------------
# Transliterates the word form of one node (token).
#------------------------------------------------------------------------------
sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $translit = $node->translit();
    my $detranslit;
    if(defined($translit))
    {
        my $table = $self->table();
        my $maxl = $self->maxl();
        $detranslit = translit::prevest($table, $translit, $maxl);
    }
    $node->set_attr('form', $detranslit);
}



#------------------------------------------------------------------------------
# Returns maximum of two values.
#------------------------------------------------------------------------------
sub max2
{
    my $a = shift;
    my $b = shift;
    return $a>=$b ? $a : $b;
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2W::Deromajize

=head1 DESCRIPTION

Based on W2W::Translit, but quickly hacked together to detransliterate Japanese
from Romaji translit to Katakana/Hiragana form. To be made much nicer when
there is time...

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>
Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008 – 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
