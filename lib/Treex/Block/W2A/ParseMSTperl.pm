package Treex::Block::W2A::ParseMSTperl;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::BaseChunkParser';

use Treex::Tool::Parser::MSTperl::Config;
use Treex::Tool::Parser::MSTperl::Parser;
use Treex::Tool::Parser::MSTperl::Sentence;
use Treex::Tool::Parser::MSTperl::Node;

use Treex::Core::Resource qw(require_file_from_share) ; 

# Look for model under "model_dir/model_name.model"
# and its config "model_dir/model_name.config".
# Absolute path is needed if not a model from share.
has 'model_from_share' => (
    is => 'ro',
    isa => 'Bool',
    default => '1',
);

has 'model_name' => (
    is => 'ro',
    isa => 'Str',
    default => 'conll_2007',
);

has 'model_dir' => (
    is => 'ro',
    isa => 'Str',
    default => 'data/models/mst_perl_parser/en',
);

# use features from aligned tree
has 'parallel_parsing' => ( isa => 'Bool', is => 'ro', default => '0' );
# the language of the tree which is already parsed and is accessed via the
# 'aligned_' prefix, eg. en
has 'alignment_language' => ( isa => 'Str', is => 'ro', default => 'cs' );
# alignment type to use, eg. int.gdfa
has 'alignment_type' => ( isa => 'Str', is => 'ro', default => 'int.gdfa' );
# use alignment info from the other tree
has 'alignment_is_backwards' => ( isa => 'Bool', is => 'ro', default => '0' );

has parser => (
    is => 'ro',
    isa => 'Treex::Tool::Parser::MSTperl::Parser',
    init_arg => undef,
    builder => '_build_parser',
    lazy => 1,
    );

sub _build_parser {
    my ($self) = @_;

    my $base_name = $self->model_dir . '/' . $self->model_name;

    my $config_file = (
        $self->model_from_share
        ?
        require_file_from_share("$base_name.config", ref($self))
        :
        "$base_name.config"
    );
    my $config = Treex::Tool::Parser::MSTperl::Config->new(
        config_file => $config_file,
        training => 0
    );
    
    my $parser = Treex::Tool::Parser::MSTperl::Parser->new(
        config => $config
    );
    my $model_file = (
        $self->model_from_share
        ?
        require_file_from_share("$base_name.model", ref($self))
        :
        "$base_name.model"
    );
    $parser->load_model($model_file);

    return $parser;
}

sub parse_chunk {
    my ( $self, @a_nodes ) = @_;
    # assumes that a_nodes are ordered correctly
    # (BaseChunkParser ensures that now)

    # get alignment mapping
    my $alignment_hash = $self->_get_alignment_hash( $a_nodes[0]->get_bundle() );

    # convert from treex data structures to parser data structures
    my $sentence = $self->_get_sentence($alignment_hash, @a_nodes);
    
    # run the parser
    my @node_parents = @{$self->parser->parse_sentence($sentence)};

    # set nodes' parents
    my @roots = ();
    foreach my $a_node (@a_nodes) {
        my $parent_index_1based = shift @node_parents;
        if ($parent_index_1based) { # node's parent is a real node
            my $parent_index_0based = $parent_index_1based - 1;
            my $parent_node = $a_nodes[$parent_index_0based];
            $a_node->set_parent($parent_node);
        } else { # == 0; node's parent is the technical root of the chunk
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
        foreach my $field_name (@{$self->parser->config->field_names}) {
            my $field_value = $self->_get_field_value(
                $a_node, $field_name, $alignment_hash);
            if (defined $field_value) {
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
        nodes => \@nodes,
        config => $self->parser->config
    );
    
    return $sentence;
}

# get alignment mapping
sub _get_alignment_hash {
    my ($self, $bundle) = @_;
    
    my $alignment_hash;
    if ( $self->parallel_parsing && $self->alignment_is_backwards ) {
        # we need to provide the other direction of the relation
        $alignment_hash = {};
        # gets root of aligned Analytical tree
        my $aligned_root =
            $bundle->get_tree( $self->alignment_language, 'A' );
        # foreach node in the aligned-language tree
        foreach my $aligned_node ( $aligned_root->get_descendants ) {
            # find all nodes which it is aligned to
            my ( $nodes, $types ) = $aligned_node->get_aligned_nodes();
            if ($nodes) {
                # store alignment mapping to this node
                for (my $i = 0; $i < @{$nodes}; $i++) {
                    my $node = $nodes->[$i];
                    my $type = $types->[$i];
                    my $id = $node->id;
                    # alignment is of the desired type
                    if ($self->alignment_type eq $type) {
                        # store mapping: node_id->aligned_node
                        push @{ $alignment_hash->{$id} }, $aligned_node;
                    }
                }
            }
        }
    } else {
        #Node->get_aligned_nodes() will be used directly
        $alignment_hash = undef;
    }

    return $alignment_hash;
}

sub _get_field_value {
    my ( $self, $node, $field_name, $alignment_hash ) = @_;

    my $field_value = '';
    
    my ( $field_name_head, $field_name_tail ) = split( /_/, $field_name, 2 );
    # combined field (contains '_')
    if ($field_name_tail) {
        
        # field on aligned nodes
        if ($field_name_head eq 'aligned') {
            $field_value = $self->_get_field_value(
                $node, $field_name_tail, $alignment_hash
            );
        
        # dummy or ignored field
        } elsif ($field_name_head eq 'dummy') {
            $field_value = '';
        
        # special field
        } else {
            
            # ord of the parent node
            if ($field_name eq 'parent_ord') {
                $field_value = '0'; # will be filled by the parser
            
            # language-specific coarse grained tag
            } elsif ($field_name eq 'coarse_tag') {
                $field_value = $self->get_coarse_grained_tag($node->get_attr('tag'));
                
            } else {
                die "Incorrect field $field_name!";
            }
        }
    
    # ordinary field (does not contain '_')
    } else {
        $field_value = $node->get_attr($field_name);
    }

    return $field_value;
}

sub get_coarse_grained_tag {
    log_fatal 'get_coarse_grained_tag must be implemented in derived classes';
    my ( $self, $tag ) = @_;
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
The default is the English model
C<share/data/models/mst_perl_parser/en/conll_2007.model>
(and C<conll_2007.config> in the same directory).

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
