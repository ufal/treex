package Treex::Tool::Parser::MSTperl::ParsedSentencesCombiner;

use Moose;
use Carp;

use Treex::Tool::Parser::MSTperl::Parser;
use Treex::Tool::Parser::MSTperl::Sentence;

use Graph 0.94;
use Graph::ChuLiuEdmonds 0.05;    #returns MINIMUM spanning tree

sub parse_sentence {

    # (Array[Treex::Tool::Parser::MSTperl::Sentence] $sentence_parses)
    my ( $self, $sentence_parses, $weights ) = @_;

    # parse sentence (does not modify $sentence)
    my $sentence_parsed = $self->parse_sentences_internal($sentence_parses, $weights);
    return $sentence_parsed->toParentOrdsArray();
}

sub parse_sentence_internal {

    # (Array[Treex::Tool::Parser::MSTperl::Sentence] $sentence_parses)
    my ( $self, $sentence_parses, $weights ) = @_;

    # copy the sentence (do not modify $sentence directly)
    my $sentence_working_copy = $sentence_parses->[0]->copy_nonparsed();

    # run the actual metaparsing
    my $edges = $self->parse_sentence_full($sentence_working_copy, $sentence_parses, $weights);

    #results
    foreach my $edge ( @$edges ) {
        my ( $parent, $child ) = @$edge;
        $sentence_working_copy->setChildParent( $child, $parent );
    }
    
    return $sentence_working_copy;
}

# name kept for simílarity with MSTperl::Parser
# even though there is no other way of parsing the sentence than "full"
sub parse_sentence_full {
    my ($self, $sentence_working_copy, $sentence_parses, $weights_ar) = @_;

    my $sentence_length = $sentence_working_copy->len();

    my @weights = defined $weights_ar ? @$weights_ar : (1) x scalar(@$sentence_parses);

    # initialize a complete graph
    my $graph = Graph->new(
        vertices => [ ( 0 .. $sentence_length ) ]
    );
    foreach my $child ( @{ $sentence_working_copy->nodes } ) {
        foreach my $parent ( @{ $sentence_working_copy->nodes_with_root } ) {
            if ( $child->ord == $parent->ord ) {
                next;
            } else {
                $graph->add_weighted_edge($parent->ord, $child->ord, 0);
            }
        }
    }

    # run the parsers
    # add up the parses into edge weights in $graph
    use List::MoreUtils qw( each_array );
    my $it = each_array( @{$sentence_parses}, @weights );
    while ( my ($sentence_parse, $weight) = $it->() ) {
        foreach my $child (@{$sentence_parse->nodes}) {
            my $child_ord = $child->ord;
            my $parent_ord = $child->parentOrd;
            # MaxST needed but MinST is computed -> need to use weight as -weight
            # (the meaning is -= 1*weight)
            $graph->set_edge_weight( $parent_ord, $child_ord, 
                $graph->get_edge_weight($parent_ord, $child_ord) - $weight );
        }
    }

    # find the maximum spanning tree
    my $msts = $graph->MST_ChuLiuEdmonds($graph);

    # return result
    my @edges = $msts->edges;
    return \@edges;
}

1;

__END__


=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::ParsedSentencesCombiner --
a metaparser that combines several parse trees
into one using a Maximum Spanning Tree algortihm.

=head1 METHODS

=over 4

=item $parser->parse_sentence($sentence_parses_ar [,$weights_ar]);

Combines parses of a sentence 
(array ref of instances of L<Treex::Tool::Parser::MSTperl::Sentence>)
using the Chu-Liu-Edmonds MST algorithm.
Can also perform a weighted combination, if C<$weights_ar> is specified;
it must be a reference to an array of numbers
of the same length as C$sentence_parses_ar>.
Returns an array of parent ords.

=item $parser->parse_sentence_internal($sentence, $sentence_parses_ar [,$weights_ar]);

The internal method that does the combination.
Directly modifies C<$sentence> (and returns it).

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
