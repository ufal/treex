package Treex::Block::W2A::ParseMSTperl;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::BaseChunkParser';

use Treex::Tool::Parser::MSTperl::FeaturesControl;
use Treex::Tool::Parser::MSTperl::Parser;
use Treex::Tool::Parser::MSTperl::Sentence;
use Treex::Tool::Parser::MSTperl::Node;

# TODO: make easier to set
has 'model_name' => ( is => 'ro', isa => 'Str', default => 'conll_2007' );
has 'model_dir' => ( is => 'ro', isa => 'Str', default => "$ENV{TMT_ROOT}/share/data/models/mst_perl_parser/en" );
# looks for model under "model_dir/model_name.model"
# and its config "model_dir/model_name.config"

#TODO: loading each model only once should be handled in different way (copied from ParseMST)
my $featuresControl;
my $parser;

sub BUILD {
    my ($self) = @_;

    if ( !$parser ) {
	my $base_name = $self->model_dir . '/' . $self->model_name;
	if ( !$featuresControl ) {
	    $featuresControl = Treex::Tool::Parser::MSTperl::FeaturesControl->new(config_file => "$base_name.config", training => 0);
	}
	$parser = Treex::Tool::Parser::MSTperl::Parser->new(featuresControl => $featuresControl);
	$parser->load_model("$base_name.model");
    }
    return;
}

sub parse_chunk {
    my ( $self, @a_nodes ) = @_;
    # assumes that a_nodes are ordered correctly (BaseChunkParser ensures that now)

    # convert from treex data structures to parser data structures
    my @nodes;
    foreach my $a_node (@a_nodes) {
	# TODO: get the fields from attributes using featuresControl and get_attr
	my @field_values;
	foreach my $field_name (@{$featuresControl->field_names}) {
	    my $field_value;
	    #if ($field_name =~ /(.+)_(.+)/) { # special field
	    if ($field_name =~ /_/) { # special field
		if ($field_name eq 'parent_ord') {
		    $field_value = '0';
		} elsif ($field_name eq 'coarse_tag') {
		    $field_value = $self->get_coarse_grained_tag($a_node->get_attr('tag'));
		} else {
		    die "Incorrect field $field_name!";
		}
	    } else {
		$field_value = $a_node->get_attr($field_name);
	    }
	    push @field_values, $field_value;
	}
	my $node = Treex::Tool::Parser::Parser::MSTperl::Node->new(fields => [@field_values], featuresControl => $featuresControl);
	push @nodes, $node;
    }
    my $sentence = Treex::Tool::Parser::Parser::MSTperl::Sentence->new(nodes => [@nodes], featuresControl => $featuresControl);
    
    # run the parser
    my @node_parents = @{$parser->parse_sentence($sentence)};
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
    my ( $self, $tag ) = @_;
    
    my $ctag;
    if ( substr( $tag, 4, 1 ) eq '-' ) {
	# no case -> Pos + Subpos
        $ctag = substr( $tag, 0, 2 );
    } else {
	# has case -> Pos + Case
        $ctag = substr( $tag, 0, 1 ) . substr( $tag, 4, 1 );
    }

    return $ctag;
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
