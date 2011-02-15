package Treex::Block::A2W::CS::AsciiQuotes;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $sentence = $bundle->get_attr('czech_target_sentence');
    $sentence =~ tr/„“/""/;
    $bundle->set_attr( 'czech_target_sentence', $sentence );
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
