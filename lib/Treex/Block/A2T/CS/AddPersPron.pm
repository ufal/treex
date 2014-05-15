package Treex::Block::A2T::CS::AddPersPron;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # Add ACT/#PersPron nodes 
    if ($t_node->is_clause_head
        && !grep { ( ( $_->functor || "" ) eq "ACT" ) || ( ( $_->formeme || "" ) eq "n:1" ) } 
        $t_node->get_echildren( { or_topological => 1 } )
        )
    {                
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

        my @anode_tags = $self->_get_anode_tags($t_node);

        my ( $person, $gender, $number );
        my ( $aux_gender, $aux_number );

        # TODO the verb can be just "to be", so take dependent adjectives into account

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
        elsif ( grep { $_ =~ /^V..S/ } @anode_tags ) {
            $number = 'sg';
        }
        # in fact, this can appear just with 'Q' gender
        elsif ( grep { $_ =~ /^V..W/ } @anode_tags ) {
            $aux_number = 'sg/pl';
            $number = 'sg';
        }
        # number position is '-'
        else {
            $aux_number = 'sg/pl';
            $number = 'sg';
        }

        if ( grep { $_ =~ /^V.Q/ } @anode_tags ) {    # napraseno !!! ve skutecnosti je poznani rodu daleko tezsi
            $aux_gender = 'fem/neut';
            $gender = 'fem';
        }
        # in fact, it can appear just in singular
        elsif ( grep { $_ =~ /^V.N/ } @anode_tags ) {
            $gender = 'neut';
        }
        # in fact, it can appear just in plural
        elsif ( grep { $_ =~ /^V.M/ } @anode_tags ) {
            $gender = 'anim';
        }
        elsif ( grep { $_ =~ /^V.Y/ } @anode_tags ) {
            $aux_gender = 'anim/inan';
            $gender = 'anim';
        }
        # in fact, it can appear just in plural
        elsif ( grep { $_ =~ /^V.T/ } @anode_tags ) {
            $aux_gender = 'inan/fem';
            $gender = 'anim';
        }
        elsif ( grep { $_ =~ /^V.H/ } @anode_tags ) {
            $aux_gender = 'fem/neut';
            $gender = 'anim';
        }
        # gender position is '-'
        else {
            $aux_gender = 'anim/inan/fem/neut';
            $gender = 'anim';
        }
        # evidence from the data - gender of the generated perspron can be anything, 
        # if the verb is in present tense and 1st or 2nd person
        #elsif ( grep {$_ =~ /^VB-.---[12]P.*/} @anode_tags ) {
        #    $gender = 'nr';
        #}

        $new_node->set_gram_person($person);
        $new_node->set_gram_gender($gender);
        $new_node->set_gram_number($number);
        $new_node->wild->{'aux_gram/number'} = $aux_number if (defined $aux_number);
        $new_node->wild->{'aux_gram/gender'} = $aux_gender if (defined $aux_gender);
    }
    return;
}

sub _get_anode_tags {
    my ($self, $t_node) = @_;
    return map { $_->tag } ( $t_node->get_lex_anode, $t_node->get_aux_anodes );
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

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
