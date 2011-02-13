package TCzechT_to_TCzechA::Add_subconjs;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

my %NUMBERPERSON2ABY = ( # 'endings' for aby/kdyby
    'S1' => 'ch',
    'S2' => 's',
    'P1' => 'chom',
    'P2' => 'ste',
);

sub process_bundle {
    my ( $self, $bundle ) = @_;

    foreach my $t_node ( $bundle->get_tree('TCzechT')->get_descendants() ) {
        process_tnode($t_node);
    }
    return;
}

sub process_tnode {
    my ($t_node) = @_;
    my $formeme = $t_node->get_attr('formeme');
    return if $formeme !~ /^v:(.+)\+/;


    # multiword conjunctions or conjunctions with expletives (pote co) are possible
    my @subconj_forms = split /_/,$1;

    my $a_node = $t_node->get_lex_anode();

    my $first_subconj_node;

    foreach my $subconj_form (@subconj_forms) {

        my $subconj_node = $a_node->get_parent()->create_child(
            {   attributes => {
                'm/form'       => $subconj_form,
                'm/lemma'      => $subconj_form,
                'afun'         => 'AuxC',
                'morphcat/pos' => 'J',
            }
            }
        );

        # the only 'flective' subordinating conjunctions are 'aby' and 'kdyby'
        if ($subconj_form =~ /^(aby|kdyby)$/) {
            my $key = ($t_node->get_attr('morphcat/number')||"").($t_node->get_attr('morphcat/person')||"");
            if ($NUMBERPERSON2ABY{$key}) {
                $subconj_node->set_attr('m/form',$subconj_form.$NUMBERPERSON2ABY{$key});
            }
        }

        if (not $first_subconj_node) {
            $subconj_node->shift_before_subtree($a_node);
            $a_node->set_parent($subconj_node);
            $first_subconj_node = $subconj_node;
        }
        else {
            $subconj_node->set_parent($first_subconj_node);
            $subconj_node->shift_after_node($first_subconj_node);
        }

        $t_node->add_aux_anodes($subconj_node);

    }

    return;
}

1;

=over

=item TCzechT_to_TCzechA::Add_subconjs

Add a-nodes corresponding to subordinating conjunctions
(accordingly to the corresponding t-node's formeme).

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
