package Treex::Block::T2A::CS::AddSubconjs;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %NUMBERPERSON2ABY = (    # 'endings' for aby/kdyby
    'S1' => 'ch',
    'S2' => 's',
    'P1' => 'chom',
    'P2' => 'ste',
);

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $formeme = $t_node->formeme;
    return if $formeme !~ /^v:(.+)\+/;

    # multiword conjunctions or conjunctions with expletives (pote co) are possible
    my @subconj_forms = split /_/, $1;

    my $a_node = $t_node->get_lex_anode();

    my ( $first_subconj_node, $prev_subconj_node );
    my (@subconj_nodes) = ();

    foreach my $subconj_form (@subconj_forms) {

        my $subconj_node = $a_node->get_parent()->create_child(
            {   'form'         => $subconj_form,
                'lemma'        => $subconj_form,
                'afun'         => 'AuxC',
                'morphcat/pos' => 'J',
            }
        );
        push @subconj_nodes, $subconj_node;

        # the only 'flective' subordinating conjunctions are 'aby' and 'kdyby'
        if ( $subconj_form =~ /^(aby|kdyby)$/ ) {
            my $key = ( $a_node->get_attr('morphcat/number') || "" ) . ( $a_node->get_attr('morphcat/person') || "" );
            if ( $NUMBERPERSON2ABY{$key} ) {
                $subconj_node->set_form( $subconj_form . $NUMBERPERSON2ABY{$key} );
            }
        }

        # hang the first subconj node above the clause
        if ( not $first_subconj_node ) {
            $subconj_node->shift_before_subtree($a_node);
            $a_node->set_parent($subconj_node);
            $first_subconj_node = $subconj_node;
            $prev_subconj_node  = $subconj_node;

            # move the is_member attribute to the conjunction
            $subconj_node->set_is_member( $a_node->is_member );
            $a_node->set_is_member();
        }
        # hang all other parts of a compound subconj under the first part
        else {
            $subconj_node->set_parent($first_subconj_node);
            $subconj_node->shift_after_node($prev_subconj_node);
            $prev_subconj_node = $subconj_node;
            
            # (first) expletive: mark all nodes including this one as belonging to the upper clause,
            # hang the next node under the expletive
            if ( $subconj_node->form =~ /^(to|toho|tomu|tom|tím)$/ and $first_subconj_node == $subconj_nodes[0] ) {
                foreach my $node (@subconj_nodes) {
                    $node->wild->{upper_clause} = 1;
                }
                $first_subconj_node = $subconj_node;
            }
            # after expletive: hang further nodes and the lexical node under the first node after the expletive 
            elsif ( @subconj_nodes >= 2 and $subconj_nodes[-2]->wild->{upper_clause} ){
                $a_node->set_parent($subconj_node);
                $first_subconj_node = $subconj_node;
            }          
        }

        $t_node->add_aux_anodes($subconj_node);
    }

    return;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::CS::AddSubconjs

=head1 DESCRIPTION

Add a-nodes corresponding to subordinating conjunctions
(according to the corresponding t-node's formeme).

=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
