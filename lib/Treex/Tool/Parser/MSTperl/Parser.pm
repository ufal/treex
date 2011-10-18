package Treex::Tool::Parser::MSTperl::Parser;

# TODO: most probably refactor to two classes, Parser and Labeller

use Moose;
use Carp;

use Treex::Tool::Parser::MSTperl::Sentence;
use Treex::Tool::Parser::MSTperl::Edge;
use Treex::Tool::Parser::MSTperl::Model;

use Graph;
use Graph::Directed;
use Graph::ChuLiuEdmonds;    #returns MINIMUM spanning tree

has config => (
    isa      => 'Treex::Tool::Parser::MSTperl::Config',
    is       => 'ro',
    required => '1',
);

has unlabelled_model => (
    isa => 'Maybe[Treex::Tool::Parser::MSTperl::Model]',
    is  => 'rw',
);

has labelled_model => (
    isa => 'Maybe[Treex::Tool::Parser::MSTperl::Model]',
    is  => 'rw',
);

sub BUILD {
    my ($self) = @_;

    if ( $self->config->unlabelledFeaturesControl ) {
        $self->unlabelled_model(
            Treex::Tool::Parser::MSTperl::Model->new(
                featuresControl => $self->config->unlabelledFeaturesControl
                )
        );
    }

    if ( $self->config->labelledFeaturesControl ) {
        $self->labelled_model(
            Treex::Tool::Parser::MSTperl::Model->new(
                featuresControl => $self->config->labelledFeaturesControl
                )
        );
    }

    return;
}

sub load_model {

    # (Str $filename)
    my ( $self, $filename_unlabelled, $filename_labelled ) = @_;

    my $result = 0;

    if ( $filename_unlabelled && $self->unlabelled_model ) {
        $result = $self->unlabelled_model->load($filename_unlabelled);
    }

    if ( $filename_labelled && $self->labelled_model ) {
        $result = $self->labelled_model->load($filename_labelled);
    }

    return $result;
}

sub parse_sentence {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence)
    my ( $self, $sentence ) = @_;

    # parse sentence (does not modify $sentence)
    my $sentence_parsed = $self->parse_sentence_unlabelled($sentence);

    return $sentence_parsed->toParentOrdsArray();
}

sub parse_sentence_unlabelled {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence)
    my ( $self, $sentence ) = @_;

    if ( !$self->unlabelled_model ) {
        croak "MSTperl parser error: There is no model for unlabelled parsing!";
    }

    # copy the sentence (do not modify $sentence directly)
    my $sentence_working_copy = $sentence->copy_nonparsed();
    my $sentence_length       = $sentence_working_copy->len();

    my $graph = Graph::Directed->new(
        vertices => [ ( 0 .. $sentence_length ) ]
    );
    my @weighted_edges;
    if ( $self->config->DEBUG ) { print "EDGES (parent -> child):\n"; }
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

            # my $score = $self->model->score_edge($edge);
            my $features = $self->config->unlabelledFeaturesControl
                ->get_all_features($edge);
            my $score = $self->unlabelled_model->score_features($features);

            # only progress and/or debug info
            if ( $self->config->DEBUG ) {
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
    if ( $self->config->DEBUG ) {
        print "GRAPH:\n";
        print join " ", @weighted_edges;
        print "\n";
    }

    $graph->add_weighted_edges(@weighted_edges);

    my $msts = $graph->MST_ChuLiuEdmonds($graph);

    if ( $self->config->DEBUG ) { print "RESULTS (parent -> child):\n"; }

    #results
    foreach my $edge ( $msts->edges ) {
        my ( $parent, $child ) = @$edge;
        $sentence_working_copy->setChildParent( $child, $parent );

        if ( $self->config->DEBUG ) {
            print "$parent -> $child\n";
        }
    }

    return $sentence_working_copy;
}

sub label_sentence {

    # (Treex::Tool::Parser::MSTperl::Sentence $sentence)
    my ( $self, $sentence ) = @_;

    if ( !$self->labelled_model ) {
        croak "MSTperl parser error: There is no model for labelling!";
    }

    # copy the sentence (do not modify $sentence directly)
    my $sentence_working_copy = $sentence->copy_nonlabelled();
    my $sentence_length       = $sentence_working_copy->len();

    # TODO

    return;
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
using L<Treex::Tool::Parser::MSTperl::Model/load>.

A model has to be loaded before sentences can be parsed.

=item $parser->parse_sentence($sentence);

Parses a sentence (instance of L<Treex::Tool::Parser::MSTperl::Sentence>). It
sets the C<parent> field of each node (instance of
L<Treex::Tool::Parser::MSTperl::Node>), i.e. a word in the sentence, and also
returns these parents as an array reference.

Any parse information already contained in the sentence gets discarded
(explicitely, by calling L<Treex::Tool::Parser::MSTperl::Sentence/clear_parse>).

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
