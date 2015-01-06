package Treex::Tool::Parser::MSTperl::Parser;

use Moose;
use Carp;

use Treex::Tool::Parser::MSTperl::Parser;
use Treex::Tool::Parser::MSTperl::Sentence;

use Graph 0.94;
use Graph::ChuLiuEdmonds 0.05;    #returns MINIMUM spanning tree

has parsers => ( is => 'rw', isa => 'ArrayRef[Treex::Tool::Parser::MSTperl::Parser]' );
has weights => ( is => 'rw', isa => 'ArrayRef[Num]', lazy => 1, builder => '_build_weights' );

sub _build_weights {
    my ($self) = @_;

    my $weights = [];
    foreach my $parser (@{$self->parsers}) {
        push @$weights, 1;
    }

    return $weights;
}

sub parse_sentence {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence)
    my ( $self, $sentence ) = @_;

    # parse sentence (does not modify $sentence)
    my $sentence_parsed = $self->parse_sentence_internal($sentence);
    return $sentence_parsed->toParentOrdsArray();
}

sub parse_sentence_internal {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence)
    my ( $self, $sentence ) = @_;

    # copy the sentence (do not modify $sentence directly)
    my $sentence_working_copy = $sentence->copy_nonparsed();

    # run the actual metaparsing
    my $edges = $self->parse_sentence_full($sentence_working_copy);

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
    my ($self, $sentence_working_copy) = @_;

    my $sentence_length = $sentence_working_copy->len();

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
    my $it = each_array( @{$self->parsers}, @{$self->weights} );
    while ( my ($parser, $weight) = $it->() ) {
        my $parsed_sentence = $parser->parse_sentence_internal($sentence_working_copy);
        foreach my $child (@{$parsed_sentence->nodes}) {
            my $child_ord = $child->ord;
            my $parent_ord = $child->parentOrd;
            # MaxST needed but MinST is computed -> need to use weight as -weight
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

Treex::Tool::Parser::MSTperl::ParserCombiner --
a metaparser that runs multiple parsers and combines the resulting parse trees
into one found as the Maximum Spanning Tree

=head1 METHODS

=over 4

=item $parser->parse_sentence($sentence);

Parses a sentence (instance of L<Treex::Tool::Parser::MSTperl::Sentence>). It
sets the C<parent> field of each node (instance of
L<Treex::Tool::Parser::MSTperl::Node>), i.e. a word in the sentence, and also
returns these parents as an array reference.

Any parse information already contained in the sentence gets discarded
(explicitely, by calling
L<Treex::Tool::Parser::MSTperl::Sentence/copy_nonparsed>).

=item $parser->parse_sentence_internal($sentence);

Does the actual parsing, returning a parsed instance of
L<Treex::Tool::Parser::MSTperl::Sentence>. The C<parse_sentence> sub is
actually only a wrapper for this method which extracts the parents of the
nodes and returns these.

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
