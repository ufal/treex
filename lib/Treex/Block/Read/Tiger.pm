package Treex::Block::Read::Tiger;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseReader';
with 'Treex::Block::Read::BaseSplitterRole';

use Moose::Util qw(apply_all_roles);
use XML::Twig;

has language => ( isa => 'Treex::Type::LangCode', is => 'ro', required => 1 );

has _twig => (
    isa    => 'XML::Twig',
    is     => 'ro',
    writer => '_set_twig',
);

sub BUILD {
    my ($self) = @_;
    $self->_set_twig( XML::Twig::->new() );
    return;
}

#------------------------------------------------------------------------------
# Returns the span (two numeric positions) of a symbol. Assumes that all
# terminals have their span stored in $node->wild->{span[01]}. The nonterminals
# may or may not have their span stored. If they do, the stored span will be
# returned. Otherwise, it will be determined recursively. The tree must be
# already built when this function is called.
#------------------------------------------------------------------------------
sub span
{
    my $node = shift;
    if(defined($node->wild->{span0}))
    {
        return ($node->wild->{span0}, $node->wild->{span1});
    }
    elsif(my @children = $node->children())
    {
        my ($span0, $span1);
        foreach my $child (@children)
        {
            my ($cspan0, $cspan1) = span($child);
            $span0 = $cspan0 if(!defined($span0) || $cspan0<$span0);
            $span1 = $cspan1 if(!defined($span1) || $cspan1>$span1);
        }
        return ($span0, $span1);
    }
    else
    {
        log_warn('Cannot determine span of node '.$node->id());
        # This is a nonterminal without children. Prevent further warnings on the same matter and set its span to zero.
        return (0, 0);
    }
}



#------------------------------------------------------------------------------
# Returns the size (number of terminals) of the span of a node.
#------------------------------------------------------------------------------
sub get_span_size
{
    my $node = shift;
    return $node->wild->{span1} - $node->wild->{span0};
}



#------------------------------------------------------------------------------
# Returns true if spans x and y overlap but neither is subset of the other.
# Returns false otherwise.
#------------------------------------------------------------------------------
sub spans_overlap
{
    my $x0 = shift;
    my $x1 = shift;
    my $y0 = shift;
    my $y1 = shift;
    log_fatal("($x0;$x1) is not a span") if($x0<0 || $x0>$x1);
    log_fatal("($y0;$y1) is not a span") if($y0<0 || $y0>$y1);
    return $x0>$y0 && $x0<$y1 && $x1>$y1 || $x0<$y0 && $x1>$y0 && $x1<$y1;
}
sub node_spans_overlap
{
    my $nodex = shift;
    my $nodey = shift;
    return spans_overlap($nodex->wild->{span0}, $nodex->wild->{span1}, $nodey->wild->{span0}, $nodey->wild->{span1});
}



#------------------------------------------------------------------------------
# Returns true if whole span x is inside y but the two spans are not identical.
# Returns false if they are identical, overlapping or span y is inside x.
#------------------------------------------------------------------------------
sub span_x_inside_y
{
    my $x0 = shift;
    my $x1 = shift;
    my $y0 = shift;
    my $y1 = shift;
    log_fatal("($x0;$x1) is not a span") if($x0<0 || $x0>$x1);
    log_fatal("($y0;$y1) is not a span") if($y0<0 || $y0>$y1);
    return $x0>=$y0 && $x1<$y1 || $x0>$y0 && $x1<=$y1;
}
sub node_span_x_inside_y
{
    my $nodex = shift;
    my $nodey = shift;
    return span_x_inside_y($nodex->wild->{span0}, $nodex->wild->{span1}, $nodey->wild->{span0}, $nodey->wild->{span1});
}



#------------------------------------------------------------------------------
# Sanity check: Are all nodes in my span my descendants?
# If they don't, they may be orphans (without incoming edge).
# It also may indicate that the tree is not projective, i.e. my span is not
# contiguous (it happens in TIGER-XML-encoded Estonian treebank).
# The real orphans are attached directly to the root.
#------------------------------------------------------------------------------
sub orphans
{
    my $node = shift;
    my $root = $node->get_root();
    # Get all nodes whose span overlaps with my span.
    my @inspan = grep {node_span_x_inside_y($_, $node)} $root->get_descendants();
    # Return all nodes in my span that are not in my subtree.
    my %descendants; map {$descendants{$_}++} $node->get_descendants();
    my @orphans_or_gap = grep {!exists($descendants{$_})} @inspan;
    # Filter out gap nodes, keep real orphans.
    return grep {$_->parent()==$root} (@orphans_or_gap);
}



#------------------------------------------------------------------------------
# Finds nodes that have no incoming edge. Now they are attached to the root by
# default but they had no incoming edge in the input XML file. Reattaches such
# nodes to the closest nonterminal whose span surrounds them.
#------------------------------------------------------------------------------
sub attach_orphans
{
    my $root = shift;
    # Get all non-root nodes.
    my @nodes = $root->get_descendants();
    # Using node references as hash keys does not work (Node methods cannot be called any more).
    # We will use node ids and thus we will need a mapping from the ids to the nodes.
    my %nodes_by_id; map {$nodes_by_id{$_->id()} = $_} @nodes;
    # Recursively search for gaps.
    my %gaps; # $gaps{$node_in_gap->id()} = $closest_node_whose_span_has_gap;
    find_gaps($root, \@nodes, \%gaps);
    # Gaps can be caused by nonprojective constructions.
    # We are now only interested in orphan nodes so filter nonprojectivities out.
    my @orphans = grep {$_->parent()==$root} map {$nodes_by_id{$_}} sort(keys(%gaps));
    foreach my $orphan (@orphans)
    {
        my $surround = $gaps{$orphan->id()};
        my $or_string = node_span_string($orphan);
        my $nt_string = node_span_string($surround);
        log_warn("ORPHAN NODE $or_string ATTACHED TO $nt_string");
        log_warn('  '.$orphan->get_address());
        # Attach the orphan to the closest surrounding phrase.
        $orphan->set_parent($surround);
        $orphan->set_edgelabel('ORPHAN');
    }
}



#------------------------------------------------------------------------------
# Finds gaps in spans of nonterminals, i.e. nodes that are in that span but are
# not dominated by the nonterminal. Such nodes could be either orphans or the
# gaps could result from nonprojective constructions. Gap nodes are stored in
# a hash and for each gap node the stored value is the closest nonterminal node
# whose span contains the gap.
#------------------------------------------------------------------------------
sub find_gaps
{
    my $node = shift;
    my $nodes = shift;
    my $gaps = shift;
    # Get all nodes in the span of the current node.
    my @inspan = ();
    if(get_span_size($node)>1)
    {
        @inspan = grep {node_span_x_inside_y($_, $node)} @{$nodes};
    }
    # If there are no inspan nodes then there are no gaps.
    if(@inspan)
    {
        # First let my children report their gaps. Then I will collect the rest.
        foreach my $child ($node->children())
        {
            find_gaps($child, $nodes, $gaps);
        }
        # Get descendants of the current node. If they fill the span, there are no gaps.
        my %descendants; map {$descendants{$_->id()}++} $node->get_descendants();
        # Record gaps in a hash so that the upper levels of the tree do not have to care about the gaps detected on lower levels.
        map {$gaps->{$_->id()} = $node} grep {!exists($descendants{$_->id()}) && !exists($gaps->{$_->id()})} @inspan;
    }
}



#------------------------------------------------------------------------------
# Debugging function. Returns a node's id and its span.
#------------------------------------------------------------------------------
sub node_span_string
{
    my $node = shift;
    my $label = '('.($node->form() ? $node->form() : $node->phrase()).')';
    return $node->id().$label.'['.$node->wild->{span0}.','.$node->wild->{span1}.']';
}



## some nodes have id that starts with -, it is invalid in xml and does
## not work with ttred.
sub fix_id {
    my $id = shift;
    if ( 0 == index $id, '-' ) {
        $id = "i$id";
    }
    return $id;
}    # fix_id

sub next_document {
    my ($self) = @_;
    my $filename = $self->next_filename();
    return if !defined $filename;
    log_info "Loading $filename...";

    my $document = $self->new_document();
    $self->_twig->setTwigRoots(
        {   s => sub {
                my ( $twig, $sentence ) = @_;
                $twig->purge;
                my $bundle = $document->create_bundle;
                my $zone   = $bundle->create_zone( $self->language, $self->selector );
                my $ptree  = $zone->create_ptree;
                my @nonterminals;
                my @terminals;
                my @edges;
                foreach my $nonterminal ($sentence->descendants('nt')) {
                    my $ch = $ptree->create_nonterminal_child();
                    push(@nonterminals, $ch);
                    apply_all_roles( $ch, 'Treex::Core::WildAttr' );
                    $ch->set_id( fix_id( $nonterminal->{att}{id} ) );
                    $ch->set_phrase( $nonterminal->{att}{cat} );
                    push @edges, [
                        $ch,
                        fix_id( $_->{att}{idref} ),
                        $_->{att}{label},
                        ]
                        for $nonterminal->children('edge');
                }
                # Position is a point between two terminals. Zero is before the first terminal.
                my $pos = 0;
                foreach my $terminal ($sentence->descendants('t')) {
                    my $ch = $ptree->create_terminal_child();
                    push(@terminals, $ch);
                    apply_all_roles( $ch, 'Treex::Core::WildAttr' );
                    $ch->set_id( fix_id( $terminal->{att}{id} ) );
                    $ch->set_form( $terminal->{att}{word} );
                    $ch->set_lemma( $terminal->{att}{lemma} );
                    $ch->set_tag( $terminal->{att}{pos} );
                    $ch->wild->{pos}   = $terminal->{att}{pos};
                    $ch->wild->{morph} = $terminal->{att}{morph};
                    # Assume that the list of terminals is ordered identically with the original word order.
                    # Then the span of each terminal can be determined incrementally.
                    $ch->wild->{span0} = $pos++;
                    $ch->wild->{span1} = $pos;
                }
                # Assume that the terminals appear in the original word order of the sentence.
                # Set the sentence attribute of the zone.
                my $sentence = join(' ', map {$_->form()} @terminals);
                $zone->set_sentence($sentence);
                foreach my $edge (@edges) {
                    my ( $parent, $child_id, $label ) = @$edge;
                    my ($child) = grep $child_id eq fix_id( $_->id ),
                        $ptree->descendants;
                    $child->set_parent($parent);
                    $child->set_edgelabel($label);
                }
                # Once the tree has been completely built we can compute the span of the nonterminals.
                foreach my $nt ($ptree, @nonterminals)
                {
                    if(!defined($nt->wild->{span0}))
                    {
                        ($nt->wild->{span0}, $nt->wild->{span1}) = span($nt);
                    }
                }
                # Once all nonterminals have spans set we can check for orphans:
                # nodes without incoming edge in the input data.
                attach_orphans($ptree);
            },    # sentence handler
        }
    );

    $self->_twig->parsefile($filename);

    return $document;
}    # next_document

1;

__END__

=head1 NAME

Treex::Block::Read::Tiger

=head1 DESCRIPTION

Document reader for the XML-based Tiger format used for storing
German TIGER Treebank.

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 PARAMETERS

=over

none

=head1 SEE

L<Treex::Block::Read::BaseReader>

=head1 AUTHOR

Jan Štěpánek <stepanek@ufal.mff.cuni.cz>
Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
