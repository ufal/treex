package Treex::Tool::Parser::MSTperl::Parser;

use Moose;

use Treex::Tool::Parser::MSTperl::Sentence;
use Treex::Tool::Parser::MSTperl::Edge;
use Treex::Tool::Parser::MSTperl::Model;

use Graph;
use Graph::Directed;
use Graph::ChuLiuEdmonds;    #returns MINIMUM spanning tree

has featuresControl => (
    isa      => 'Treex::Tool::Parser::MSTperl::FeaturesControl',
    is       => 'ro',
    required => '1',
);

has model => (
    isa => 'Treex::Tool::Parser::MSTperl::Model',
    is  => 'rw',
);

my $DEBUG = 0;

sub BUILD {
    my ( $self, $arg_ref ) = @_;

    $self->model( Treex::Tool::Parser::MSTperl::Model->new( featuresControl => $self->featuresControl ) );
}

sub load_model {

    # (Str $filename)
    my ( $self, $filename ) = @_;

    $self->model->load($filename);
}

sub parse_sentence {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence)
    my ( $self, $sentence ) = @_;

    $sentence->clear_parse();
    my $sentence_length = $sentence->len();

    my $graph = Graph::Directed->new( vertices => [ ( 0 .. $sentence_length ) ] );
    my @weighted_edges;
    if ($DEBUG) { print "EDGES (parent -> child):\n"; }
    foreach my $child ( @{ $sentence->nodes } ) {
        foreach my $parent ( @{ $sentence->nodes_with_root } ) {
            if ( $child == $parent ) {
                next;
            }

            my $edge = Treex::Tool::Parser::MSTperl::Edge->new(
                child    => $child,
                parent   => $parent,
                sentence => $sentence
            );

            # my $score = $self->model->score_edge($edge);
            my $features = $self->featuresControl->get_all_features($edge);
            my $score    = $self->model->score_features($features);

            # only progress and/or debug info
            if ($DEBUG) {
                print $parent->ord .
                    ' (' . $parent->form . ') -> ' . $child->ord .
                    ' (' . $child->form . ') score: ' . $score . "\n";
                foreach my $feature ( @{$features} ) {
                    print $feature . ", ";
                }
                print "\n";
                print "\n";
            }

            # END only progress and/or debug info

            # MaxST needed but MinST is computed -> need to normalize score as -$score
            push @weighted_edges, ( $parent->ord, $child->ord, -$score );
        }
    }

    # only progress and/or debug info
    if ($DEBUG) {
        print "GRAPH:\n";
        print join " ", @weighted_edges;
        print "\n";
    }

    # END only progress and/or debug info

    $graph->add_weighted_edges(@weighted_edges);

    my $msts = $graph->MST_ChuLiuEdmonds($graph);

    if ($DEBUG) { print "RESULTS (parent -> child):\n"; }

    #results
    foreach my $edge ( $msts->edges ) {
        my ( $parent, $child ) = @$edge;
        $sentence->setChildParent( $child, $parent );

        if ($DEBUG) { print "$parent (" . $sentence->getNodeByOrd($parent)->form . ") -> $child (" . $sentence->getNodeByOrd($child)->form . ")\n"; }
    }

    return $sentence->toParentOrdsArray();
}

1;

__END__

=pod 

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl::Parser - pure Perl implementation of MST parser

=head1 DESCRIPTION

This is a Perl implementation of the MST Parser described in
McDonald et al.:
Non-projective Dependency Parsing using Spanning Tree Algorithms
2005
in Proc. HLT/EMNLP.

=head1 METHODS

=over 4

=item $parser->load_model('modelfile.model');

Loads a model (= sets feature weights) using L<Treex::Tool::Parser::MSTperl::Model/load>.

A model has to be loaded before sentences can be parsed.

=item $parser->parse_sentence($sentence);

Parses a sentence (instance of L<Treex::Tool::Parser::MSTperl::Sentence>). It sets the 
C<parent> field of each node (instance of L<Treex::Tool::Parser::MSTperl::Node>), i.e. a 
word in the sentence, and also returns these parents as an array reference.

Any parse information already contained in the sentence gets discarded 
(explicitely, by calling L<Treex::Tool::Parser::MSTperl::Sentence/clear_parse>).

=back

=head1 AUTHORS

Rudolf Rosa <rur@seznam.cz>

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
