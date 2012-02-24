package Treex::Tool::Parser::MSTperl::Parser;

use Moose;
use Carp;

use Treex::Tool::Parser::MSTperl::Sentence;
use Treex::Tool::Parser::MSTperl::Edge;
use Treex::Tool::Parser::MSTperl::ModelUnlabelled;

use Graph 0.94;
use Graph::ChuLiuEdmonds 0.05;    #returns MINIMUM spanning tree

has config => (
    isa      => 'Treex::Tool::Parser::MSTperl::Config',
    is       => 'ro',
    required => '1',
);

has model => (
    isa => 'Maybe[Treex::Tool::Parser::MSTperl::ModelUnlabelled]',
    is  => 'rw',
);

sub BUILD {
    my ($self) = @_;

    $self->model(
        Treex::Tool::Parser::MSTperl::ModelUnlabelled->new(
            config => $self->config,
            )
    );

    return;
}

sub load_model {

    # (Str $filename)
    my ( $self, $filename ) = @_;

    return $self->model->load($filename);
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

    if ( !$self->model ) {
        croak "MSTperl parser error: There is no model for unlabelled parsing!";
    }

    # copy the sentence (do not modify $sentence directly)
    my $sentence_working_copy = $sentence->copy_nonparsed();
    my $sentence_length       = $sentence_working_copy->len();

    my $graph = Graph->new(
        vertices => [ ( 0 .. $sentence_length ) ]
    );
    my @weighted_edges;
    if ( $self->config->DEBUG >= 2 ) { print "EDGES (parent -> child):\n"; }
    foreach my $child ( @{ $sentence_working_copy->nodes } ) {
        foreach my $parent ( @{ $sentence_working_copy->nodes_with_root } ) {
            if ( $child == $parent ) {
                next;
            }

            my $edge = Treex::Tool::Parser::MSTperl::Edge->new(
                child    => $child,
                parent   => $parent,
                sentence => $sentence_working_copy
            );

            my $features = $self->config->unlabelledFeaturesControl
                ->get_all_features($edge);
            my $score = $self->model->score_features($features);

            # only progress and/or debug info
            if ( $self->config->DEBUG >= 2 ) {
                print $parent->ord . ' ' . $parent->fields->[1] .
                    ' -> ' . $child->ord . ' ' . $child->fields->[1] .
                    ' score: ' . $score . "\n";
                print $parent->ord .
                    ' -> ' . $child->ord .
                    ' score: ' . $score . "\n";
                foreach my $feature ( @{$features} ) {
                    print $feature . ", ";
                }
                print "\n";
                print "\n";
            }

            # MaxST needed but MinST is computed
            #  -> need to normalize score as -$score
            push @weighted_edges, ( $parent->ord, $child->ord, -$score );
        }
    }

    # only progress and/or debug info
    if ( $self->config->DEBUG >= 2 ) {
        print "GRAPH:\n";
        print join " ", @weighted_edges;
        print "\n";
    }

    $graph->add_weighted_edges(@weighted_edges);

    my $msts = $graph->MST_ChuLiuEdmonds($graph);

    if ( $self->config->DEBUG >= 2 ) { print "RESULTS (parent -> child):\n"; }

    #results
    foreach my $edge ( $msts->edges ) {
        my ( $parent, $child ) = @$edge;
        $sentence_working_copy->setChildParent( $child, $parent );

        if ( $self->config->DEBUG >= 2 ) {
            print "$parent -> $child\n";
        }
    }

    return $sentence_working_copy;
}

1;

__END__


=pod

=for Pod::Coverage BUILD

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

Loads an unlabelled and/or a labelled model (= sets feature weights)
using L<Treex::Tool::Parser::MSTperl::ModelBase/load>.

A model has to be loaded before sentences can be parsed.

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

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
