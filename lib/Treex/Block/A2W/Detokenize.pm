package Treex::Block::A2W::Detokenize;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    my $a_root = $zone->get_atree;
    my $sentence = "";
    foreach my $a_node ($a_root->get_descendants({ordered=>1})) {
        $sentence .= $a_node->form;
        $sentence .= " " if !$a_node->no_space_after;
    }
    $zone->set_sentence($sentence);
}

1;

=over

=item Treex::Block::A2W::Detokenize

Creates the target sentence string from analytical tree. It uses
no_space_afters attribute for (not)inserting spaces between tokens.

=back

=cut

# Copyright 2011 David Marecek
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
