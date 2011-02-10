package SEnglishA_to_SEnglishT::Fix_imperatives;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $t_root = $bundle->get_tree('SEnglishT');

    foreach my $tnode ( grep { $_->formeme eq "v:fin" } $t_root->get_eff_children ) {
        my $anode = $tnode->get_lex_anode;

        next if ( $tnode->get_attr('sentmod') || '' ) eq 'inter';
        next if not $anode or $anode->tag ne "VB";
        next if grep { $_->tag     eq "MD" } $tnode->get_aux_anodes;
        next if grep { $_->formeme eq "n:subj" } $tnode->get_eff_children;

        $tnode->set_attr( 'gram/verbmod', 'imp' );
        $tnode->set_attr( 'sentmod',      'imper' );

        my $perspron = $tnode->create_child;
        $perspron->shift_before_node($tnode);

        $perspron->set_attr( 't_lemma',     '#PersPron' );
        $perspron->set_attr( 'functor',     'ACT' );
        $perspron->set_attr( 'formeme',     'n:subj' );            # !!! elided?
        $perspron->set_attr( 'nodetype',    'complex' );
        $perspron->set_attr( 'gram/sempos', 'n.pron.def.pers' );
        $perspron->set_attr( 'gram/number', 'pl' );                # default: vykani
        $perspron->set_attr( 'gram/gender', 'anim' );
        $perspron->set_attr( 'gram/person', '2' );

    }
}

1;

=over

=item SEnglishA_to_SEnglishT::Fix_imperatives

Imperatives are recognized (at least some of), and provided with
a new PersPron node and corrected gram/verbmod value.

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
