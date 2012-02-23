package Treex::Tool::Parser::MSTperl;

use Moose;
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

    my $base_name = $self->model_dir . '/' . $self->model_name;

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
underlying packages and should be sufficient for the basic tasks.

Please note that the parser does B<non-projective> parsing and is therefore
best for parsing of non-projective languages (e.g. Czech or Dutch). Projective
languages (e.g. English) can be parsed by MSTperl as well, but non-projective
edges can sometimes appear in the output. To do real projective parsing, it
would be necessary to change the core algorithm of the parser (Eisner would
have to be used in stead of Chu-Liu-Edmonds).

Please note that the parser does B<dependency> parsing,
producing a dependency tree as its output. The parser cannot be used to
produce phrase-structure trees.

Models necessary for these tools
can be
downloaded from
L<http://ufallab.ms.mff.cuni.cz/tectomt/share/data/models/mst_perl_parser/>
for the parser and from
L<http://ufallab.ms.mff.cuni.cz/tectomt/share/data/models/labeller_mira/> for
the labeller.
Many models for Czech and a few models for English are provided.

If you have a dependency treebank, you can train your own model - see
L<Treex::Tool::Parser::MSTperl::TrainerLabelling> and
L<Treex::Tool::Parser::MSTperl::TrainerUnlabelled>. The parameters and the
feature set are tuned for parsing of Czech language, so doing a little tuning
might be helpful when parsing other languages (all of the necessary settings
can be done in the config file - see L<Treex::Tool::Parser::MSTperl::Config>).

No models are provided for languages other than Czech or English. If you want
to use the parser for another language, you have to train your own model.

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

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
