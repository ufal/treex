package Treex::Block::W2A::ParseMSTperl;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::BaseChunkParser';
with 'Treex::Block::W2A::AnalysisWithAlignedTrees';

use Treex::Tool::Parser::MSTperl::Config;
use Treex::Tool::Parser::MSTperl::Parser;
use Treex::Tool::Parser::MSTperl::Sentence;
use Treex::Tool::Parser::MSTperl::Node;

use Treex::Core::Resource qw(require_file_from_share);

# Look for model under "model_dir/model_name.model"
# and its config "model_dir/model_name.config".
# Absolute path is needed if not a model from share.
has 'model_from_share' => (
    is      => 'ro',
    isa     => 'Bool',
    default => '1',
);

has 'model_name' => (
    is      => 'ro',
    isa     => 'Str',
    required => 1,
);

has 'model_dir' => (
    is      => 'ro',
    isa     => 'Str',
    default => 'data/models/parser/mst_perl',
);

has 'model_gz' => (
    is      => 'ro',
    isa     => 'Bool',
    default => '0',
);

has parser => (
    is       => 'ro',
    isa      => 'Treex::Tool::Parser::MSTperl::Parser',
    init_arg => undef,
    builder  => '_build_parser',
    lazy     => 1,
);

sub _build_parser {
    my ($self) = @_;

    my $base_name = $self->model_dir . '/' . $self->model_name;

    my $config_file = (
        $self->model_from_share
        ?
            require_file_from_share( "$base_name.config", ref($self) )
        :
            "$base_name.config"
    );
    my $config = Treex::Tool::Parser::MSTperl::Config->new(
        config_file => $config_file,
        training    => 0,
	DEBUG => 0,
    );

    my $parser = Treex::Tool::Parser::MSTperl::Parser->new(
        config => $config
    );
    my $model_file_name = (
	$self->model_gz
	?
	"$base_name.model.gz"
	:
	"$base_name.model"
	);

    my $model_file = (
        $self->model_from_share
        ?
            require_file_from_share( $model_file_name, ref($self) )
        :
            $model_file_name
    );
    $parser->load_model($model_file);

    return $parser;
}

# TODO process_start
sub BUILD {
    my $self = shift;
    
    # enforce parser initialization
    $self->parser;
    
    return;
}

sub parse_chunk {
    my ( $self, @a_nodes ) = @_;

    # assumes that a_nodes are ordered correctly
    # (BaseChunkParser ensures that now)

    # get alignment mapping
    my $alignment_hash =
        $self->_get_alignment_hash( $a_nodes[0]->get_bundle() );

    # convert from treex data structures to parser data structures
    my $sentence = $self->_get_sentence( $alignment_hash, @a_nodes );

    # run the parser
    my @node_parents = @{ $self->parser->parse_sentence($sentence) };

    # set nodes' parents
    my @roots = ();
    foreach my $a_node (@a_nodes) {
        my $parent_index_1based = shift @node_parents;
        if ($parent_index_1based) {    # node's parent is a real node
            my $parent_index_0based = $parent_index_1based - 1;
            my $parent_node         = $a_nodes[$parent_index_0based];
            $a_node->set_parent($parent_node);
        } else {
            # == 0; node's parent is the technical root of the chunk
            # keep the original parent (the technical root of the sentence)
            push @roots, $a_node;
        }
    }

    # return roots of all parse subtrees
    return @roots;
}

# convert from treex data structures to parser data structures
sub _get_sentence {
    my ( $self, $alignment_hash, @a_nodes ) = @_;

    # create objects of class Treex::Tool::Parser::MSTperl::Node
    my @nodes;
    foreach my $a_node (@a_nodes) {

        # get field values
        my @field_values;
        foreach my $field_name ( @{ $self->parser->config->field_names } ) {
            my $field_value = $self->_get_field_value(
                $a_node, $field_name, $alignment_hash
            );
            if ( defined $field_value ) {
                push @field_values, $field_value;
            } else {
                push @field_values, '';
            }
        }

        # create Node object
        my $node = Treex::Tool::Parser::MSTperl::Node->new(
            fields => \@field_values,
            config => $self->parser->config
        );

        # store the Node object
        push @nodes, $node;
    }

    # create object of class Treex::Tool::Parser::MSTperl::Sentence
    my $sentence = Treex::Tool::Parser::MSTperl::Sentence->new(
        nodes  => \@nodes,
        config => $self->parser->config
    );

    return $sentence;
}

sub get_coarse_grained_tag {
    log_warn 'get_coarse_grained_tag should be implemented in derived classes';
    my ( $self, $tag ) = @_;

    return substr( $tag, 0, 1 );
}
1;

__END__

=head1 NAME

Treex::Block::W2A::ParseMSTperl

=head1 DECRIPTION

MST parser (maximum spanning tree dependency parser by R. McDonald)
is used to determine the topology of a-layer trees.
This is its reimplementation in Perl, with simplified MIRA algorithm
(single-best MIRA is used).

Settings are provided via a config file accompanying the model file.
The script loads the model C<model_dir/model_name.model>
and its config <model_dir/model_name.config>.

You must set a model to use the parser, e.g. C<model_name=en/conll_2007_best>
(if the default model dir C<data/models/parser/mst_perl> suits you;
otherwise, also set C<model_dir> to a directory in which you have downloaded the
models from
C<http://ufallab.ms.mff.cuni.cz/tectomt/share/data/models/mst_perl_parser/> or
obtained in another way.)

It is not sensible to change the config file unless you decide to train
your own model.
However if you B<do> decide to train your own model, then see
L<Treex::Tool::Parser::MSTperl::Config>.

TODO: provide a treex interface for the trainer?

=head1 SEE ALSO

L<Treex::Block::W2A::BaseChunkParser> base clase (see the C<reparse> parameter)

L<Treex::Block::W2A::MarkChunks> this block can be used before parsing
to improve the performance by marking chunks (phrases)
that are supposed to form a (dependency) subtree

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
