package Treex::Block::A2T::CS::AddPersPron;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    if ($t_node->is_clause_head
        && !grep { ( ( $_->functor || "" ) eq "ACT" ) || ( ( $_->formeme || "" ) eq "n:1" ) } $t_node->get_echildren( { or_topological => 1 } )
        )
    {

        # There is an auxiliary reflexive
        if ( my $auxr = first { my $a = $_->get_lex_anode(); $a and $a->afun eq 'AuxR' }
                 $t_node->get_echildren( { or_topological => 1 } ) ){

            $auxr->set_functor('ACT');
            $auxr->set_formeme('drop');

            $auxr->set_gram_gender('neut');
            $auxr->set_gram_person('3');
            $auxr->set_gram_number('sg');
            return;
        }                    
                
        my $new_node = $t_node->create_child;
        $new_node->set_t_lemma('#PersPron');
        $new_node->set_functor('ACT');
        $new_node->set_formeme('drop');

        #$new_node->set_attr( 'ord',     $t_node->get_attr('ord') - 0.1 );
        #$new_node->set_id($t_node->generate_new_id );
        $new_node->set_nodetype('complex');
        $new_node->set_gram_sempos('n.pron.def.pers');
        $new_node->set_is_generated(1);
        $new_node->shift_before_node($t_node);

        my @anode_tags = map { $_->tag } ( $t_node->get_lex_anode, $t_node->get_aux_anodes );

        my ( $person, $gender, $number );

        if ( grep { $_ =~ /^(V.|J,).....1/ } @anode_tags ) { # include 'kdybychom', 'abychom'
            $person = "1";
        }
        elsif ( grep { $_ =~ /^(V.|J,).....2/ } @anode_tags ) { # include 'kdybys(te)', 'abys(te)'
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
        elsif ( grep { $_ =~ /^V.N/ } @anode_tags ) {
            $gender = 'neut';
        }
        # evidence from the data - gender of the generated perspron can be anything, 
        # if the verb is in present tense and 1st or 2nd person
        #elsif ( grep {$_ =~ /^VB-.---[12]P.*/} @anode_tags ) {
        #    $gender = 'nr';
        #}
        else {
            $gender = 'anim';
        }

        $new_node->set_gram_person($person);
        $new_node->set_gram_gender($gender);
        $new_node->set_gram_number($number);
    }
    return;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::CS::AddPersPron

=head1 DESCRIPTION

New Czech nodes with t_lemma #PersPron corresponding to unexpressed ('prodropped') subjects of finite clauses
are added.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
