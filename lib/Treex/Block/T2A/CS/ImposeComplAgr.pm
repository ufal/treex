package TCzechT_to_TCzechA::Impose_compl_agr;

use utf8;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $t_root = $bundle->get_tree('TCzechT');

    foreach my $t_compl ( grep { $_->get_attr('formeme') =~ /adj:compl/ } $t_root->get_descendants ) {
        my ($t_clause_head) = $t_compl->get_eff_parents;
        while (
            $t_clause_head->get_attr('formeme') !~ /^v.+(fin|rc)/
            and not $t_clause_head->is_root
            and not $t_clause_head->get_parent->is_root
            )
        {
            ($t_clause_head) = $t_clause_head->get_eff_parents;
        }

        if ($t_clause_head) {
            my ($t_subj) = grep {
                $_ ne $t_compl and $_->get_attr('formeme') =~ /1/
            } $t_clause_head->get_eff_children( { ordered => 1 } );
            if ($t_subj) {
                my $a_compl = $t_compl->get_lex_anode;
                my $a_subj  = $t_subj->get_lex_anode;
                my $a_finverb  = $t_clause_head->get_lex_anode;

                # The category can be already set by previous blocks.
                # E.g. Impose_pron_z_agr sets gender for "jedna" in
                # "Byla to jedna z vdov." So, don't overwrite it.
                foreach my $category (qw(case)) {
                    if ($a_compl->get_attr("morphcat/$category") eq '.'){
                       $a_compl->set_attr("morphcat/$category", $a_subj->get_attr("morphcat/$category"));
                    }
                }

                foreach my $category (qw(number gender)) {
                    if ($a_compl->get_attr("morphcat/$category") eq '.'){
                       $a_compl->set_attr("morphcat/$category", $a_finverb->get_attr("morphcat/$category"));
                    }
                }
            }
        }
    }
    return;
}

1;

=over

=item TCzechT_to_TCzechA::Impose_compl_agr

Copy the values of morphological categories gender, number and case
according to the adjectival complement agreement (plus agreement of adjectives
in copula constructions), i.e., so far only from the subject into the complement.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
