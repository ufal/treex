package SCzechA_to_SCzechT::Add_PersPron;

use 5.008;
use strict;
use warnings;

use base qw(TectoMT::Block);

sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        my $t_root = $bundle->get_tree('SCzechT');

        foreach my $t_node (
            grep {
                $_->get_attr('is_clause_head')
                    and
                    not grep { ( $_->get_attr('formeme') || "" ) eq "n:1" } $_->get_eff_children
            }
            $t_root->get_descendants
            )
        {

            my $new_node = $t_node->create_child;
            $new_node->set_attr( 't_lemma',     '#PersPron' );
            $new_node->set_attr( 'functor',     'ACT' );
            $new_node->set_attr( 'formeme',     'n:1' );
            $new_node->set_attr( 'deepord',     $t_node->get_attr('deepord') - 0.1 );
            $new_node->set_attr( 'id',          $t_node->generate_new_id );
            $new_node->set_attr( 'nodetype',    'complex' );
            $new_node->set_attr( 'gram/sempos', 'n.pron.def.pers' );
            my @anode_tags = map { $_->get_attr('m/tag') } ( $t_node->get_lex_anode, $t_node->get_aux_anodes );

            my ( $person, $gender, $number );

            if ( grep { $_ =~ /^V......1/ } @anode_tags ) {
                $person = "1";
            }
            elsif ( grep { $_ =~ /^V......2/ } @anode_tags ) {
                $person = "2";
            }
            else {
                $person = "3";
            }

            if ( grep { $_ =~ /^V..P/ } @anode_tags ) {
                $number = 'pl';
            }
            else {
                $number = 'sg';
            }

            if ( grep { $_ =~ /^V.Q/ } @anode_tags ) {    # napraseno !!! ve skutecnosti je poznani rodu daleko tezsi
                $gender = 'fem';
            }
            if ( grep { $_ =~ /^V.N/ } @anode_tags ) {
                $gender = 'neut';
            }
            else {
                $gender = 'anim';
            }

            $new_node->set_attr( 'gram/person', $person );
            $new_node->set_attr( 'gram/gender', $gender );
            $new_node->set_attr( 'gram/number', $number );

        }
    }
}

1;

=over

=item SCzechA_to_SCzechT::Add_PersPron

New SCzechT nodes with t_lemma #PersPron corresponding to unexpressed
('prodropped') subjects of finite clauses.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
