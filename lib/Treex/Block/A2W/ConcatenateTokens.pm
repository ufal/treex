package Treex::Block::A2W::ConcatenateTokens;
use utf8;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    my $a_root = $zone->get_atree();
    my $sentence = join ' ', grep { !/#[A-Z]/ } map { $_->form } $a_root->get_descendants( { ordered => 1 } );
    $zone->set_sentence($sentence);
    return;
}

1;

=over

=item Treex::Block::A2W::ConcatenateTokens

Creates the target sentence string simply by concatenation of word forms
joined by spaces. You must apply detokenization after this block
to delete spaces before/after punctuation etc.


=back

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
