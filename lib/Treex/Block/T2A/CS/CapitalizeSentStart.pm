package TCzechT_to_TCzechA::Capitalize_sent_start;

use 5.008;
use strict;
use warnings;
use utf8;

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $a_root = $bundle->get_tree('TCzechA');
    my $t_root = $bundle->get_tree('TCzechT');

    my @dsp_aroots = grep { defined $_ } map { $_->get_lex_anode() }
        grep { $_->get_attr('is_dsp_root') } $t_root->get_descendants();

    # Technical root should have just one child unless something (parsing) went wrong.
    # Anyway, we want to capitalize the very first word in the sentence.
    my $first_root = $a_root->get_children( { first_only => 1 } );

    foreach my $a_sent_root ( grep {defined} ( $first_root, @dsp_aroots ) ) {
        my ($first_word) =
            grep { $_->get_attr('morphcat/pos') ne 'Z' and ( $_->get_attr('m/form') || '' ) ne '„' }
            $a_sent_root->get_descendants( { ordered => 1, add_self => 1 } );

        # skip empty sentences and first words with no form
        next if !$first_word || !defined $first_word->get_attr('m/form');

        # in direct speech, capitalization is allowed only after the opening quote
        my $prev_node = $first_word->get_prev_node;
        next if $prev_node and ($prev_node->get_attr('morphcat/pos')||'') ne "Z";

        $first_word->set_attr( 'm/form', ucfirst( $first_word->get_attr('m/form') ) );

    }
    return;
}

1;

=over

=item TCzechT_to_TCzechA::Capitalize_sent_start

Capitalize the first letter of the first (non-punctuation)
token in the sentence, and the same for direct speeches.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
