package Treex::Block::A2P::ParseStanford;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );
has _parser     => ( is       => 'rw' );

use Treex::Tools::Parser::Stanford;

sub BUILD {
    my ($self) = @_;
    $self->_set_parser( Treex::Tools::Parser::Stanford->new( { language => $self->language } ) );
    return;
}

sub process_zone {
    my ( $self, $zone ) = @_;

    my $m_root  = $zone->get_atree;
    my @m_nodes = $m_root->get_children;
    log_fatal "Impossible to parse an empty sentence. Bundle id=" . $zone->get_bundle->id
        unless @m_nodes;

    my @words  = map { $_->form } @m_nodes;

    my $tree_root = $self->_parser->parse(@words);
    my @root_children = @{$tree_root->children};
    my $old_root = $root_children[0];

    my $new_root = $zone->create_ptree;
    _convert_subtree($old_root, $new_root);
}

sub _convert_subtree{
    # the 'old' nodes come from the wrapper, 'new' nodes are created using Treex::Core
    my ( $old_node, $new_node ) = @_;

    my @old_children = @{$old_node->children};

    if (@old_children > 0) { # terminal
        $new_node->set_form( $old_node->term );
        $new_node->tag($old_node->tag ); # what?
#        $new_node->{'#name'} = 'terminal'; # dirty: low-level pml
    }

    else { # non-terminal
#        $new_node->{'#name'} = 'nonterminal'; # dirty: low-level pml
        $new_node->phrase($old_node->term );  # what

        foreach my $old_child (@old_children) {
            my $new_child = $new_node->create_child;
            convert_subtree($old_child, $new_child);
        }
    }
}

1;

=pod

=over

=item Treex::Block::A2P::ParseStanford

Expects tokenized nodes (a-tree),
creates phrase-structure trees using Stanford constituency parser.
(not in ::EN:: in hope that there will be models for more languages)

=back

=cut

# Copyright 2011 Nathan Green, Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.





