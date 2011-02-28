package Treex::Block::A2W::CS::AsciiQuotes;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    my $sentence = $zone->sentence;
    $sentence =~ tr/„“/""/;
    $zone->set_sentence($sentence);
    return;
}

1;

=over

=item Treex::Block::A2W::CS::AsciiQuotes

Correct Czech quotation marks („ and “) are changed to incorrect ASCII (").
This hack is usefull for BLEU comparisons
(when ASCII quotes are used in reference translations).

=back

=cut

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
