package Treex::Block::A2T::CS::AddPersPron;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    if ( $t_node->is_clause_head 
            && !grep { (($_->functor || "") eq "ACT") || (( $_->formeme || "" ) eq "n:1") } $t_node->get_echildren ) {
                
        my $new_node = $t_node->create_child;
        $new_node->set_t_lemma('#PersPron');
        $new_node->set_functor('ACT');
        $new_node->set_formeme('n:1');

        #$new_node->set_attr( 'ord',     $t_node->get_attr('ord') - 0.1 );
        #$new_node->set_id($t_node->generate_new_id );
        $new_node->set_nodetype('complex');
        $new_node->set_attr( 'gram/sempos', 'n.pron.def.pers' );
        $new_node->shift_before_node($t_node);

        my @anode_tags = map { $_->tag } ( $t_node->get_lex_anode, $t_node->get_aux_anodes );

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

1;

=over

=item Treex::Block::A2T::CS::AddPersPron

New Czech nodes with t_lemma #PersPron corresponding to unexpressed
('prodropped') subjects of finite clauses.

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, David Marecek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
