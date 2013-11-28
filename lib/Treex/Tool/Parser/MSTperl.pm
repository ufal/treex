package Treex::Tool::Parser::MSTperl;

use Moose;
use 5.010;
use File::Spec;

use Treex::Tool::Parser::MSTperl::Config;
use Treex::Tool::Parser::MSTperl::Node;
use Treex::Tool::Parser::MSTperl::Sentence;
use Treex::Tool::Parser::MSTperl::Parser;
use Treex::Tool::Parser::MSTperl::Labeller;

has 'model_name' => (
    is       => 'ro',
    isa      => 'Str',
    required => '1',
);

has 'model_dir' => (
    is      => 'ro',
    isa     => 'Str',
    default => '.',
);

has 'base_name' => (
    is      => 'ro',
    isa     => 'Str',
    lazy    => '1',
    builder => 'build_base_name',
);

sub build_base_name {
    my ($self) = @_;

    my $base_name = File::Spec->catfile( $self->model_dir, $self->model_name );

    return $base_name;
}

has 'config' => (
    is      => 'rw',
    isa     => 'Treex::Tool::Parser::MSTperl::Config',
    lazy    => '1',
    builder => 'build_config',
);

sub build_config {
    my ($self) = @_;

    my $config = Treex::Tool::Parser::MSTperl::Config->new(
        config_file => $self->base_name . '.config'
    );

    return $config;
}

has 'parser' => (
    is      => 'ro',
    isa     => 'Treex::Tool::Parser::MSTperl::Parser',
    lazy    => '1',
    builder => 'build_parser',
);

sub build_parser {
    my ($self) = @_;

    # Initialize the parser
    my $parser = Treex::Tool::Parser::MSTperl::Parser->new(
        config => $self->config
    );

    # Load the unlabelled parsing model
    $parser->load_model( $self->base_name . '.model' );

    return $parser;
}

has 'labeller' => (
    is      => 'ro',
    isa     => 'Treex::Tool::Parser::MSTperl::Labeller',
    lazy    => '1',
    builder => 'build_labeller',
);

sub build_labeller {
    my ($self) = @_;

    # Initialize the labeller
    my $labeller = Treex::Tool::Parser::MSTperl::Labeller->new(
        config => $self->config
    );

    # Load the labelling model
    $labeller->load_model( $self->base_name . '.lmodel' );

    return $labeller;
}

sub BUILD {
    my ($self) = @_;

    # Build the config
    $self->config;

    return;
}

sub parse_labelled {
    my ( $self, $words ) = @_;

    my $sentence          = $self->_create_sentence($words);
    my $sentence_parsed   = $self->_parse_sentence($sentence);
    my $sentence_labelled = $self->_label_sentence($sentence_parsed);

    my $parents = $sentence_parsed->toParentOrdsArray();
    my $labels  = $sentence_labelled->toLabelsArray();

    return ( $parents, $labels );
}

sub parse_unlabelled {
    my ( $self, $words ) = @_;

    my $sentence        = $self->_create_sentence($words);
    my $sentence_parsed = $self->_parse_sentence($sentence);

    my $parents = $sentence_parsed->toParentOrdsArray();

    return $parents;
}

# TODO: parse_tsv

# Each word is represented by
# (a ref to) an array of its fields (form, pos tag, lemma...)
sub _create_sentence {

    # ArrayRef[ArrayRef[Str]]
    my ( $self, $words ) = @_;

    # Create the Node objects representing the individual words
    my @nodes;
    foreach my $fields (@$words) {
        my $node = Treex::Tool::Parser::MSTperl::Node->new(
            config => $self->config,
            fields => $fields
        );
        push @nodes, $node;
    }

    # Create the Sentence object representing the whole sentence
    my $sentence = Treex::Tool::Parser::MSTperl::Sentence->new(
        config => $self->config,
        nodes  => \@nodes
    );

    return $sentence;
}

sub _parse_sentence {
    my ( $self, $sentence ) = @_;

    my $sentence_parsed = $self->parser->parse_sentence_internal($sentence);

    return $sentence_parsed;
}

sub _label_sentence {
    my ( $self, $sentence ) = @_;

    my $sentence_labelled = $self->labeller->label_sentence_internal($sentence);

    return $sentence_labelled;
}

1;

__END__


=pod

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::MSTperl - a non-projective dependency natural language
parser (pure Perl implementation of the MST parser)

=head1 SYNOPSIS

Analysis of a Czech sentence "Martin jde po ulici." ("Martin walks on the
street."), in case only the word forms are available (i.e. you do not have a
tagger which would provide you with the POS tags and/or lemmas).

In shell (or in any other way):

 # Download the config file
 wget http://ufallab.ms.mff.cuni.cz/tectomt/share/data/models/parser/mst_perl/cs/pdt_form.config
 # Download and ungzip the unlabelled parsing model
 wget http://ufallab.ms.mff.cuni.cz/tectomt/share/data/models/parser/mst_perl/cs/pdt_form.model.gz
 gunzip pdt_form.model.gz
 # Download and ungzip the deprel labelling model
 wget http://ufallab.ms.mff.cuni.cz/tectomt/share/data/models/parser/mst_perl/cs/pdt_form.lmodel.gz
 gunzip pdt_form.lmodel.gz

(the C<pdt_form> model uses only the wordforms to build dependency trees)

In Perl:

 # the words = child nodes
 my @words = (['Martin'], ['jde'], ['po'], ['ulici'], ['.']);
 # potential parent nodes
 my @words_with_root = @words;
 unshift @words_with_root, ['ROOT'];
 # i.e. @words_with_root = (['ROOT'], ['Martin'], ['jde'], ['po'], ['ulici'], ['.']);

 use Treex::Tool::Parser::MSTperl;

 # Initialize MSTperl
 my $mstperl = Treex::Tool::Parser::MSTperl->new( model_name => 'pdt_form' );

 # Parse the sentence - returns (ArrayRef[Int], ArrayRef[Str]])
 my ($parents, $deprels) = $mstperl->parse_labelled( \@words );

 # Let's see what we got:
 print "child -> parent (deprel):\n------------------------\n";
 for (my $i = 0; $i < @words; $i++) {
    my $word = $words[$i]->[0];
    my $parent_ord = $parents->[$i];
    my $parent = $words_with_root[$parent_ord]->[0];
    my $deprel = $deprels->[$i];
    print "$word -> $parent ($deprel)\n";
 }

This should return:

 child -> parent (deprel):
 ------------------------
 Martin -> jde (Sb)
 jde -> ROOT (Pred)
 po -> jde (AuxP)
 ulici -> po (Adv)
 . -> ROOT (AuxK)

which is the correct parse tree with correct deprels assigned.

=head1 DESCRIPTION

This is a Perl implementation of the MST Parser described in
McDonald et al.:
Non-projective Dependency Parsing using Spanning Tree Algorithms,
2005,
in Proc. HLT/EMNLP.

B<Treex::Tool::Parser::MSTperl> contains an unlabelled parser
(L<Treex::Tool::Parser::MSTperl::Parser>) and a dependency relation (deprel)
labeller (L<Treex::Tool::Parser::MSTperl::Labeller>), which, if chained
together, provide a labelled dependency parser.

The B<Treex::Tool::Parser::MSTperl> package serves as a wrapper for the
underlying packages and should be sufficient for the basic tasks. For any
special needs, feel free to use the underlying packages directly.

Please note that the parser does B<non-projective> parsing and is therefore
best for parsing of non-projective languages (e.g. Czech or Dutch). Projective
languages (e.g. English) can be parsed by MSTperl as well, but non-projective
edges can sometimes appear in the output. To do real projective parsing, it
would be necessary to change the core algorithm of the parser (Eisner would
have to be used in stead of Chu-Liu-Edmonds).

Please note that the parser does B<dependency> parsing,
producing a dependency tree as its output. The parser cannot be used to
produce phrase-structure trees.

Models necessary for these tools can be downloaded from
L<http://ufallab.ms.mff.cuni.cz/tectomt/share/data/models/mst_perl_parser/>.
The C<.model> files are unlabelled parsing models and C<.lmodel> are labelling
models. Many models for Czech and a few models for English are provided.

If you have a dependency treebank, you can train your own model - see
L<Treex::Tool::Parser::MSTperl::TrainerLabelling> and
L<Treex::Tool::Parser::MSTperl::TrainerUnlabelled>. The parameters and the
feature set in the C<.config> files are tuned for parsing of Czech language,
so doing a little tuning might be helpful when parsing other languages (all of
the necessary settings can be done in the config file - see
L<Treex::Tool::Parser::MSTperl::Config>).

No models are currently provided for languages other than Czech or English. If
you want to use the parser for another language, you have to train your own
model.

=head1 METHODS

=over 4

=item my $mstperl = Treex::Tool::Parser::MSTperl->new( model_dir => '.', model_name => 'pdt_form' );

Creates an instance of MSTperl, capable of parsing sentences, using the config
file C<model_dir/model_name.config> (required), the unlabelled parsing model
file C<model_dir/model_name.model> (required) and the labelling model file
C<model_dir/model_name.lmodel> (required only for labelled parsing). The
required files can be downloaded from
L<http://ufallab.ms.mff.cuni.cz/tectomt/share/data/models/mst_perl_parser/>;
or, you can create your own config file, train your own model(s) following
your config and use these files for parsing.

The C<model_dir> parameter is optional and defaults to C<.> (i.e. the current
directory). The C<model_name> parameter is required.

=item my ($parents, $deprels) = $mstperl->parse_labelled($sentence);

Performs labelled parsing of the sentence.

The sentence is represented as (a reference to) an array of words of the
sentence. A word is represented as (a reference to) an array of I<fields>,
required by the config. I.e. if you look into the config, you will find e.g.:

 field_names:
  - form
  - lemma
  - coarse_tag
  - parent_ord
  - afun

These are the fields used by the models. Their meaning depends on the treebank
used for training the models. We typically used PDT for Czech models and CoNLL
for English models. (The coarse tag often stands for the first two characters
of the full POS tag. For Czech, the coarse tag devised by Collins is used.)

The fields specified in the config file as the C<parent_ord> and the C<label>,
e.g.:

 parent_ord: parent_ord
 label: afun

are the fields computed by the unlabelled parser (C<parent_ord>) and the
labeller (C<label>). Obviously these are not to be specified on the input.

A sentence I<"The sheep eat grass."> to be parsed by using such a config would
be then represented e.g. as:

 $sentence = [
    ["The", "the", "DT"],
    ["sheep", "sheep", "NN"],
    ["eat", "eat", "VB"],
    ["grass", "grass", "NN"],
    [".", ".", "."],
 ];

MSTperl returns two array refs. The first one describes the dependency tree
structure by listing a parent node for each word of the sentence, represented
by an integer. The numbering of the parents is 1-based, C<0> standing for the
artificial root node. The second one contains deprels assigned to the words
(or, to be more accurate, to the edges between each word and its parent), as
strings.

=item my $parents = $mstperl->parse_unlabelled($sentence);

Similar to C<parse_labelled()>, but only unlabelled parsing is performed (a
labelling model is not used) and only the parents are returned.

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
