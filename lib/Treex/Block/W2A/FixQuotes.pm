package Treex::Block::W2A::FixQuotes;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_atree {
    my ( $self, $atree ) = @_;

    # This block applies only to sentences with even number of quotation marks
    my @nodes = $atree->get_descendants( { ordered => 1 } );

    my @quotes = grep { $_->form =~ /^(["“”„‟«»]|''|``)$/ } @nodes;
    return if @quotes < 2 || @quotes % 2;

    for ( my $i = 0; $i < @nodes and @quotes; ++$i ) {

        # go up to the first quote of the current pair
        next if ( $nodes[$i] != $quotes[0] );

        # take the current pair out of the list
        my $left_q  = shift @quotes;
        my $right_q = shift @quotes;

        # We rather leave this sentence unchanged if non-matching quotes are found
        return if !$self->can_be_pair_quotes( $left_q->form, $right_q->form );
        # We avoid cases involving coordination
        next if $left_q->is_coap_root or $right_q->is_coap_root;

        # try to find the highest node between the quotes
        my $hi_node = $i < @nodes - 1 ? $nodes[ $i + 1 ] : $nodes[ $i - 1 ];
        my $hi_node_depth = $hi_node->get_depth();
        my $j;

        for ( $j = $i + 1; $j < @nodes; ++$j ) {

            # we are at the second quote -- finish the search for the highest node
            if ( $nodes[$j] == $right_q ) {
                last;
            }
            # skip terminal punctuation, we don't want to hang the quotes under it
            if ( $nodes[$j]->form =~ /[\.?!]/ ){
                next;
            }
            if ( $nodes[$j]->get_depth() < $hi_node_depth ) {
                $hi_node       = $nodes[$j];
                $hi_node_depth = $hi_node->get_depth();
            }
        }
        
        # skip singularities (can happen if there's nothing between the quotes)
        next if ( $hi_node == $right_q or $hi_node == $left_q );

        # move any possible children of the quotes to the quotes' current parents
        map { $_->set_parent( $left_q->get_parent ) } $left_q->get_children();
        map { $_->set_parent( $right_q->get_parent ) } $right_q->get_children();

        # move the quotes under the highest node in between them
        $left_q->set_parent($hi_node);
        $right_q->set_parent($hi_node);

    }

    return;
}

sub can_be_pair_quotes {
    my ( $self, $l, $r ) = @_;
    return 1 if $l eq q{``}  && $r eq q{''};     # LaTeX-like
    return 1 if $l eq q{"}   && $r eq q{"};      # vertical ASCII
    return 1 if $l eq q{“} && $r eq q{”};    # English,...
    return 1 if $l eq q{«}  && $r eq q{»};     # French,... guillemets
    return 1 if $l eq q{„} && $r eq q{‟};    # German, Czech,...
    return 1 if $l eq q{»}  && $r eq q{«};     # Danish
    return 1 if $l eq q{„} && $r eq q{”};    # Dutch
    return 0;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::W2A::FixQuotes

=head1 DESCRIPTION

In a-trees, quotation marks should depend on the root of the quoted subtree.
E.g. in I<He said "I sleep"> the quotes should depend on I<sleep>, not on I<said>.

This block tries to fix parser inconsistencies by a simple heuristic: 
hanging paired question marks below the topmost node (tree-depth-wise) between them 
(word-order-wise).

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
