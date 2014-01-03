package Treex::Block::T2A::CS::AddSubconjs;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddSubconjs';

my %NUMBERPERSON2ABY = (    # 'endings' for aby/kdyby
    'S1' => 'ch',
    'S2' => 's',
    'P1' => 'chom',
    'P2' => 'ste',
);

override 'postprocess' => sub {

    my ( $self, $t_node, $a_node, $subconj_nodes ) = @_;
    my ( $expletive, $first_after ) = ( 0, 0 );

    foreach my $subconj_node (@$subconj_nodes) {

        my $subconj_form = $subconj_node->form;

        # the only 'flective' subordinating conjunctions are 'aby' and 'kdyby'
        if ( $subconj_form =~ /^(aby|kdyby)$/ ) {
            my $key = ( $a_node->get_attr('morphcat/number') || "" ) . ( $a_node->get_attr('morphcat/person') || "" );
            if ( $NUMBERPERSON2ABY{$key} ) {
                $subconj_node->set_form( $subconj_form . $NUMBERPERSON2ABY{$key} );
            }
        }

        # (first) expletive: mark all nodes including this one as belonging to the upper clause,
        if ( $subconj_node->form =~ /^(to|toho|tomu|tom|tím)$/ and not $expletive ) {

            foreach my $node (@$subconj_nodes) {
                if ( not $expletive ) {
                    $node->wild->{upper_clause} = 1;
                    if ( $node == $subconj_node ) {
                        $expletive = $node;
                    }
                }

                # hang the first node after the expletive right under it
                elsif ( $expletive and not $first_after ) {
                    $node->set_parent($expletive);
                    $first_after = $node;
                }

                # hang all further nodes under the first one after the expletive
                else {
                    $node->set_parent($first_after);
                }
            }
        }
    }

    # rehang lexical a-node under the first node after the expletive, if applicable
    if ($first_after) {
        $a_node->set_parent($first_after);
    }

    return;
};


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::CS::AddSubconjs

=head1 DESCRIPTION

Add a-nodes corresponding to subordinating conjunctions
(according to the corresponding t-node's formeme).

Czech-specific: inflecting conjunctions 'aby', 'kdyby', handling clause membership
for expletive 'to'.

=head1 AUTHORS 

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
