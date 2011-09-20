package Treex::Block::W2A::ParseMSTperl;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::BaseChunkParser';

use Treex::Tool::Parser::MSTperl::FeaturesControl;
use Treex::Tool::Parser::MSTperl::Parser;
use Treex::Tool::Parser::MSTperl::Sentence;
use Treex::Tool::Parser::MSTperl::Node;

use Treex::Core::Resource qw(require_file_from_share) ; 

# TODO: make easier to set
has 'model_name' => ( is => 'ro', isa => 'Str', default => 'conll_2007' );
#has 'model_dir' => ( is => 'ro', isa => 'Str', default => "$ENV{TMT_ROOT}/share/data/models/mst_perl_parser/en" );
has 'model_dir' => ( is => 'ro', isa => 'Str', default => "data/models/mst_perl_parser/en" );
# looks for model under "model_dir/model_name.model"
# and its config "model_dir/model_name.config"

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

    my $config_file = require_file_from_share("$base_name.config");
    my $featuresControl = Treex::Tool::Parser::MSTperl::FeaturesControl->new(config_file => $config_file, training => 0);
    
    my $parser = Treex::Tool::Parser::MSTperl::Parser->new(featuresControl => $featuresControl);
    my $model_file = require_file_from_share("$base_name.model");
    $parser->load_model($model_file);

    return $parser;
}

sub parse_chunk {
    my ( $self, @a_nodes ) = @_;
    # assumes that a_nodes are ordered correctly (BaseChunkParser ensures that now)

    # convert from treex data structures to parser data structures
    my @nodes;
    foreach my $a_node (@a_nodes) {
	# TODO: get the fields from attributes using featuresControl and get_attr
	my @field_values;
	foreach my $field_name (@{$self->parser->featuresControl->field_names}) {
	    my $field_value;
	    #if ($field_name =~ /(.+)_(.+)/) { # special field
	    if ($field_name =~ /_/) { # special field
		if ($field_name eq 'parent_ord') {
		    $field_value = '0'; # will be filled by the parser
		} elsif ($field_name eq 'coarse_tag') {
		    $field_value = $self->get_coarse_grained_tag($a_node->get_attr('tag'));
		} elsif ($field_name =~ 'dummy_.*') {
		    $field_value = '';
		} else {
		    die "Incorrect field $field_name!";
		}
	    } else {
		$field_value = $a_node->get_attr($field_name);
	    }
	    if (defined $field_value) {
		push @field_values, $field_value;
	    } else {
		push @field_values, '';
	    }
	}
	my $node = Treex::Tool::Parser::MSTperl::Node->new(fields => \@field_values, featuresControl => $self->parser->featuresControl);
	push @nodes, $node;
    }
    my $sentence = Treex::Tool::Parser::MSTperl::Sentence->new(nodes => \@nodes, featuresControl => $self->parser->featuresControl);
    
    # run the parser
    my @node_parents = @{$self->parser->parse_sentence($sentence)};
    # TODO: maybe root should be contained?

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

sub get_coarse_grained_tag {
    log_fatal 'get_coarse_grained_tag must be implemented in derived clases';
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
C<$ENV{TMT_ROOT}/share/data/models/mst_perl_parser/en/conll_2007.model>
(and C<conll_2007.config> in the same directory).

It is not sensible to change the config file unless you decide to train
your own model.
However if you B<do> decide to train your own model, then see
L<Treex::Tool::Parser::MSTperl::FeaturesControl>.

TODO: provide a treex interface for the trainer?

=head1 SEE ALSO

L<Treex::Block::W2A::BaseChunkParser> base clase (see the C<reparse> parameter)

L<Treex::Block::W2A::MarkChunks> this block can be used before parsing
to improve the performance by marking chunks (phrases)
that are supposed to form a (dependency) subtree

=head1 COPYRIGHT

Copyright 2011 Rudolf Rosa
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
