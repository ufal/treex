package TCzechA_to_TCzechW::Detokenize;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

use utf8;

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $a_root = $bundle->get_tree('TCzechA');
    my $sentence = "";
    foreach my $a_node ($a_root->get_descendants({ordered=>1})) {
        $sentence .= $a_node->get_attr('m/form');
        $sentence .= " " if !$a_node->get_attr('m/no_space_after');
    }
    $bundle->set_attr('czech_target_sentence', $sentence);
}

1;

=over

=item TCzechA_to_TCzechW::Detokenize

This block detokenizes Czech target analytical tree using the 'no_space_after' attributes and writes down the target sentence.

=back

=cut

# Copyright 2011 David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
