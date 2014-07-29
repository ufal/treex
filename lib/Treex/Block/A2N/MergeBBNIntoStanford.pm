package Treex::Block::A2N::MergeBBNIntoStanford;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_ntree {
    my ( $self, $nroot ) = @_;
    my %stanford_spans;

    foreach my $nnode ( $nroot->get_descendants() ) {
        if ( not _is_bbn($nnode) ) {
            $stanford_spans{ join( ':', _get_span($nnode) ) } = $nnode;
        }
    }

    foreach my $nnode ( $nroot->get_descendants() ) {

        # process all BBN n-nodes
        if ( _is_bbn($nnode) ) {

            # check if we can enrich a Stanford node with the same (or very similar) span
            my ( $ne_lo, $ne_hi ) = _get_span($nnode);
            foreach my $ne_lo_inner ( $ne_lo, $ne_lo - 1, $ne_lo - 2, $ne_lo + 1, $ne_lo + 2 ) {
                my $span = join( ':', ( $ne_lo_inner, $ne_hi ) );
                if ( $stanford_spans{$span} ) {
                    $stanford_spans{$span}->wild->{bbn_type} = $nnode->ne_type;
                    last;
                }
            }

            # remove the BBN node and rehang its children
            map { $_->set_parent( $nnode->get_parent() ) } $nnode->get_children();

            $nnode->remove();
        }
    }

    # replace Stanford NE types by those copied from BBN nodes
    foreach my $nnode ( $nroot->get_descendants() ) {
        if ( $nnode->wild->{bbn_type} ) {
            $nnode->wild->{stanford_type} = $nnode->ne_type;
            $nnode->set_ne_type( $nnode->wild->{bbn_type} );
        }
    }
}

sub _is_bbn {
    my ($nnode) = @_;
    return length $nnode->ne_type > 2;
}

sub _get_span {
    my ($nnode) = @_;
    my @anodes = sort { $a->ord <=> $b->ord } $nnode->get_anodes();
    return ( $anodes[0]->ord, $anodes[-1]->ord );
}

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2N::NestEntities – merging BBN named entities into Stanford NER output

=head1 DESCRIPTION

BBN named entities are either merged as a more detailed entity type into
Stanford NER output, or discarded.

Nested NEs from both Stanford and BBN are expected. 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
