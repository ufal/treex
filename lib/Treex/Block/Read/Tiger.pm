package Treex::Block::Read::Tiger;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseReader';
use Moose::Util qw(apply_all_roles);
use XML::Twig;

has bundles_per_doc => (
    is      => 'ro',
    isa     => 'Int',
    default => 0,
);

has language => ( isa => 'Treex::Type::LangCode', is => 'ro', required => 1 );

has _twig => (
    isa    => 'XML::Twig',
    is     => 'ro',
    writer => '_set_twig',
);

sub BUILD {
    my ($self) = @_;
    if ( $self->bundles_per_doc ) {
        $self->set_is_one_doc_per_file(0);
    }
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
                foreach my $edge (@edges) {
                    my ( $parent, $child_id, $label ) = @$edge;
                    my ($child) = grep $child_id eq fix_id( $_->id ),
                        $ptree->descendants;
                    $child->set_parent($parent);
                    $child->set_edgelabel($label);
                    if(defined($child->phrase()))
                    {
                        $child->set_phrase($child->phrase().'/'.$label);
                    }
                    else
                    {
                        $child->set_tag($child->tag().'/'.$label);
                    }
                }
                # Once the tree has been completely built we can compute the span of the nonterminals.
                foreach my $nt (@nonterminals)
                {
                    if(!defined($nt->wild->{span0}))
                    {
                        ($nt->wild->{span0}, $nt->wild->{span1}) = span($nt);
                    }
                }
                # Once all nonterminals have spans set we can check for orphans:
                # nodes that are covered by a node's span but are not descendants of that node.
                # (This means that the p-tree is nonprojective, which is an error.
                # In p-trees read from TIGER-XML it could mean that there was a node without incoming edge.)
                foreach my $nt (@nonterminals) {
                    my @orphans = orphans($nt);
                    if(@orphans) {
                        my $orphans = join(', ', map {node_span_string($_)} (@orphans));
                        my $nt_string = node_span_string($nt);
                        log_warn("ORPHAN NODES $orphans not dominated by $nt_string");
                        log_info("             ".$nt->get_address());
                    }
                }
                #log_info 'Sentence ' . $ptree->id;
            },    # sentence handler
        }
    );

    $self->_twig->parsefile($filename);
    $self->_twig->purge;

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
