package Treex::Block::A2W::CS::Detokenize;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    my $a_root   = $zone->get_atree();
    my $sentence = '';
    foreach my $a_node ( $a_root->get_descendants( { ordered => 1 } ) ) {
        $sentence .= $a_node->form;
        $sentence .= ' ' if !$a_node->no_space_after;
    }
    $zone->set_sentence($sentence);
}

1;

=over

=item Treex::Block::A2W::CS::Detokenize

This block detokenizes Czech target analytical tree using the 'no_space_after' attributes and writes down the target sentence.

=back

=cut

# Copyright 2011 David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
