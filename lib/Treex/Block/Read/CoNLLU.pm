package Treex::Block::Read::CoNLLU;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
use File::Slurp;
use Try::Tiny;
extends 'Treex::Block::Read::BaseCoNLLReader';

sub next_document
{
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;

    my $document = $self->new_document();
    foreach my $tree ( split /\n\s*\n/, $text )
    {
        my @lines  = split( /\n/, $tree );

        # Skip empty sentences (if any sentence is empty at all,
        # typically it is the first or the last one because of superfluous empty lines).
        next unless(@lines);
        my $comment = '';
        my $bundle  = $document->create_bundle();
        # The default bundle id is something like "s1" where 1 is the number of the sentence.
        # If the input file is split to multiple Treex documents, it is the index of the sentence in the current output document.
        # But we want the input sentence number. If the Treex documents are later exported to one file again, the sentence ids should remain unique.
        # Note that this is only the default sentence id for files that do not contain their own sentence ids. If they do, it will be overwritten below.
        my $sentid = $self->sent_in_file() + 1;
        my $sid = $self->sid_prefix().'s'.$sentid;
        $bundle->set_id($sid);
        $self->set_sent_in_file($sentid);
        my $zone = $bundle->create_zone( $self->language, $self->selector );
        my $aroot = $zone->create_atree();
        $aroot->set_id($sid.'/'.$self->language());
        my @parents = (0);
        my @nodes   = ($aroot);
        my $sentence_read_from_input_text = 0; # if the (now mandatory) text attribute was present, do not reset zone->sentence to concatenation of nodes!
        my $sentence;
        my $printed_up_to = 0;
        # Information about the current fused token (see below).
        my $fufrom;
        my $futo;
        my $fuform;
        my @funodes = ();
        my $funspaf; # no space after the fused token?
        my $fumisc; # MISC column of fused token line, except SpaceAfter=No, which is stored in $funspaf
        my %egraph; # enhanced dependency relations
        my @empty_nodes; # attributes of empty nodes, including leaf empty nodes

        LINE:
        foreach my $line (@lines)
        {
            next LINE if($line =~ m/^\s*$/);
            if ($line =~ s/^#\s*//)
            {
                # sent_id metadata sentence-level comment
                if ($line =~ m/^sent_id(?:\s*=\s*|\s+)(.*)/)
                {
                    my $sid = $1;
                    my $zid = $self->language();
                    # Some CoNLL-U files already have sentence ids with "/language" suffix while others don't.
                    if ($sid =~ s-/(.+)$--)
                    {
                        $zid = $1;
                    }
                    # Make sure that there are no additional slashes.
                    $sid =~ s-/.*$--;
                    $zid =~ s-/.*$--;
                    $bundle->set_id( $sid );
                    $aroot->set_id( "$sid/$zid" );
                }
                # text metadata sentence-level comment
                elsif ($line =~ m/^text\s*=\s*(.*)/)
                {
                    my $text = $1;
                    $zone->set_sentence($text);
                    $sentence_read_from_input_text = 1;
                }
                # any other sentence-level comment
                else
                {
                    $comment .= "$line\n";
                }
                next LINE;
            }
            # Since UD v2, the FORM and LEMMA columns may contain spaces, thus we can only use the TAB character as column separator.
            my ( $id, $form, $lemma, $upos, $xpos, $feats, $head, $deprel, $deps, $misc, $rest ) = split(/\t/, $line);
            log_warn("Extra columns: '$rest'") if($rest);
            # There may be empty nodes (they participate in the enhanced graph but not in the basic tree).
            if ($id =~ m/^\d+\.\d+$/)
            {
                $self->process_empty_node($id, $form, $lemma, $upos, $xpos, $feats, $deps, $misc, \%egraph, \@empty_nodes);
                next LINE;
            }
            # There may be fused tokens consisting of multiple syntactic words (= nodes).
            elsif ($id =~ m/(\d+)-(\d+)/)
            {
                ($fufrom, $futo, $fuform, $funspaf, $fumisc) = $self->process_multi_word_token($1, $2, $form, $misc);
                $printed_up_to = $futo;
                $sentence .= $fuform if(defined($fuform));
                $sentence .= ' ' unless($funspaf);
                next LINE;
            }
            # Add the current word to the sentence text unless it has been covered by a multi-word token.
            elsif ($id > $printed_up_to)
            {
                $sentence .= $form if(defined($form));
                $sentence .= ' ' if(any {$_ eq 'SpaceAfter=No'} (split(/\|/, $misc)));
            }
            my $newnode = $aroot->create_child();
            $newnode->shift_after_subtree($aroot);
            # Some applications (e.g., PML-TQ) require that the node id be unique treebank-wide.
            # Thus we will make the sentence id part of node id, assuming that sentence id is unique.
            $newnode->set_id($bundle->id().'/'.$id);
            # Nodes can become members of multiword tokens only after their ords are set.
            if (defined($futo))
            {
                # Add the current node to the current MWT. Store the MWT if this is its last node.
                ($fufrom, $futo, $fuform, $funspaf, $fumisc) = $self->store_multi_word_token($newnode, $id, $fufrom, $futo, $fuform, $funspaf, $fumisc, \@funodes);
            }
            $self->store_node_attributes($newnode, $form, $lemma, $upos, $xpos, $feats, $deprel);
            # The enhanced relations can be stored as wild attributes.
            # However, we need to first collect and store them separately, and
            # once the entire graph has been read, we have to collapse the
            # empty nodes into long relations.
            if ($deps && $deps ne '_')
            {
                my @deps = split(/\|/, $deps);
                my @edeps = grep {defined($_)} (map {my $x = $_; $x =~ m/^(\d+(?:\.\d+)?):(.+)$/ ? [$1, $2] : undef} (split(/\|/, $deps)));
                my $m = scalar(@deps);
                my $n = scalar(@edeps);
                if($m!=$n)
                {
                    log_fatal("POČET HRAN NESEDÍ $m --> $n: $deps");
                }
                $egraph{$id} = \@edeps;
            }
            if ($misc && $misc ne '_')
            {
                # Store specific (expected) MISC attributes to dedicated node attributes.
                # Store all other MISC attributes as wild attributes.
                $self->store_misc_attributes($newnode, $misc);
            }
            push(@nodes, $newnode);
            push(@parents, $head);
        }
        # All nodes have been read. Now we can connect them with their parents.
        for(my $i = 1; $i <= $#nodes; $i++)
        {
            $nodes[$i]->set_parent($nodes[$parents[$i]]);
        }
        # Process the information we have collected about the enhanced graph
        # and store it at suitable places of the tree.
        $self->store_enhanced_graph($bundle, \@nodes, \%egraph, \@empty_nodes);
        # Set the zone sentence text.
        $sentence =~ s/\s+$//;
        unless($sentence_read_from_input_text)
        {
            $zone->set_sentence($sentence);
        }
        $bundle->wild->{comment} = $comment;
    }
    return $document;
}



#------------------------------------------------------------------------------
# Reads an empty node and saves the information in a temporary hash. We will
# store it in the Treex structures after all normal nodes have been read.
#------------------------------------------------------------------------------
sub process_empty_node
{
    my $self = shift;
    my $id = shift;
    my $form = shift;
    my $lemma = shift;
    my $upos = shift;
    my $xpos = shift;
    my $feats = shift;
    my $deps = shift;
    my $misc = shift;
    my $egraph = shift; # hash reference
    my $empty_nodes = shift; # array reference
    if ($deps && $deps ne '_')
    {
        my @edeps = grep {defined($_)} (map {my $x = $_; $x =~ m/^(\d+(?:\.\d+)?):(.+)$/ ? [$1, $2] : undef} (split(/\|/, $deps)));
        $egraph->{$id} = \@edeps;
    }
    # Drawing long edges over empty nodes will help to remember that there was an empty inner node
    # but nothing more. Some treebanks feature empty leaves (e.g. copulae in Ukrainian), although
    # it is not licensed by the guidelines; such leaf nodes would be lost. Also, some treebanks
    # assign word forms and morphological annotation to empty nodes, which would be lost. Treex
    # currently cannot represent an empty node as a Node object. So we must store them as wild
    # attributes of the bundle.
    my %empty_node =
    (
        'id'    => $id,
        'form'  => $form,
        'lemma' => $lemma,
        'upos'  => $upos,
        'xpos'  => $xpos,
        'feats' => $feats,
        # We keep deps only for the case that this is a leaf node, which will disappear in the collapsed graph.
        # Unlike deps of normal, inner empty nodes, we do not expect these to be manipulated, only preserved and written again.
        ###!!! This no longer holds with the new implementation of empty nodes.
        ###!!! Once the new implementation has become stable, we can stop storing deps here.
        'deps'  => $deps,
        'misc'  => $misc
    );
    push(@{$empty_nodes}, \%empty_node);
}



#------------------------------------------------------------------------------
# Reads the introductory line of a multi-word token. Returns a list of
# variables. Their values will be used later. A multi-word token does not have
# its own node, so nothing will now be stored in the tree. The multi-word token
# (fused word in Treex terminology) corresponds to multiple syntactic words
# (tree nodes).
# Example (German):
# 2-3   zum   _     _
# 2     zu    zu    ADP
# 3     dem   der   DET
#------------------------------------------------------------------------------
sub process_multi_word_token
{
    my $self = shift;
    my $fufrom = shift;
    my $futo = shift;
    my $fuform = shift;
    my $misc = shift;
    my $funspaf;
    my $fumisc;
    # MISC may contain other information than SpaceAfter=No and we must preserve it.
    unless($misc eq '_')
    {
        my @misc = split(/\|/, $misc);
        if(any {$_ eq 'SpaceAfter=No'} (@misc))
        {
            $funspaf = 1;
        }
        @misc = grep {$_ ne 'SpaceAfter=No'} (@misc);
        if (scalar(@misc) > 0)
        {
            $fumisc = join('|', @misc);
        }
    }
    return ($fufrom, $futo, $fuform, $funspaf, $fumisc);
}



#------------------------------------------------------------------------------
# Nodes can become members of multiword tokens only after their ords are set.
# Call this for a node that is covered by the most recently declared multi-word
# token.
#------------------------------------------------------------------------------
sub store_multi_word_token
{
    my $self = shift;
    my $node = shift; # the new node to add to a fused token
    my $id = shift; # the id (ord) of the node
    my $fufrom = shift;
    my $futo = shift;
    my $fuform = shift;
    my $funspaf = shift;
    my $fumisc = shift;
    my $funodes = shift; # array reference; the MWT member nodes are collected here
    if (defined($futo))
    {
        if ($id <= $futo)
        {
            push(@{$funodes}, $node);
        }
        # Once we have added the last node of the MWT, store the MWT.
        if ($id >= $futo)
        {
            if (scalar(@{$funodes}) >= 2)
            {
                $funodes->[0]->set_fused_form($fuform);
                $funodes->[0]->set_fused_misc($fumisc);
                for (my $i = 0; $i < $#{$funodes}; $i++)
                {
                    $funodes->[$i]->set_fused_with_next(1);
                }
                if ($funspaf)
                {
                    $funodes->[-1]->set_no_space_after(1);
                }
            }
            else
            {
                log_warn "Fused token $fufrom-$futo $fuform was announced but less than 2 nodes were found";
            }
            $fufrom = undef;
            $futo = undef;
            $fuform = undef;
            splice(@{$funodes});
            $funspaf = undef;
            $fumisc = undef;
        }
    }
    return ($fufrom, $futo, $fuform, $funspaf, $fumisc);
}



#------------------------------------------------------------------------------
# Stores UD node attributes in a Node object.
#------------------------------------------------------------------------------
sub store_node_attributes
{
    my $self = shift;
    my $node = shift;
    my $form = shift;
    my $lemma = shift;
    my $upos = shift;
    my $xpos = shift;
    my $feats = shift;
    my $deprel = shift;
    $node->set_form($form);
    $node->set_lemma($lemma);
    # Tred and PML-TQ should preferably display upos as the main tag of the node.
    $node->set_tag($upos);
    $node->set_conll_cpos($upos);
    $node->set_conll_pos($xpos);
    $node->set_conll_feat($feats);
    $node->iset()->set_upos($upos);
    if ($feats ne '_')
    {
        $node->iset()->add_ufeatures(split(/\|/, $feats));
        # UD features that are not defined in Interset are now stored
        # as subfeatures of the 'other' feature of Interset. Unfortunately,
        # the 'other' feature will not be saved with the Treex document.
        # In order to save it, we must make it a wild attribute of the node.
        my $other = $node->iset()->other();
        if(defined($other) && ref($other) eq 'HASH')
        {
            $node->wild()->{iset_other} = $other;
        }
    }
    # Deprel is not defined if the node is empty (that is, enhanced only).
    if (defined($deprel) && $deprel ne '_')
    {
        $node->set_deprel($deprel);
        $node->set_conll_deprel($deprel);
    }
}



#------------------------------------------------------------------------------
# Searches for specific MISC attributes for which we have dedicated attributes.
# Moves them to the dedicated attributes if found. Stores the remaining MISC
# attributes as wild attributes.
#------------------------------------------------------------------------------
sub store_misc_attributes
{
    my $self = shift;
    my $node = shift; # the node whose MISC is being stored
    my $misc = shift; # the tenth column of the CoNLL-U file
    if ($misc && $misc ne '_')
    {
        my @misc = split(/\|/, $misc);
        # Check whether MISC contains SpaceAfter=No.
        my $n0 = scalar(@misc);
        @misc = grep {$_ ne 'SpaceAfter=No'} (@misc);
        my $n1 = scalar(@misc);
        if ($n1 < $n0)
        {
            $node->set_no_space_after(1);
        }
        # Check whether MISC contains transliteration of the word form.
        my @translit = map {my $x = $_; $x =~ s/^Translit=//; $x} (grep {m/^Translit=(.+)$/} (@misc));
        if (scalar(@translit) > 0)
        {
            $node->set_translit($translit[0]);
            @misc = grep {!m/^Translit=/} (@misc);
        }
        # Check whether MISC contains transliteration of the lemma.
        my @ltranslit = map {my $x = $_; $x =~ s/^LTranslit=//; $x} (grep {m/^LTranslit=(.+)$/} (@misc));
        if (scalar(@ltranslit) > 0)
        {
            $node->set_ltranslit($ltranslit[0]);
            @misc = grep {!m/^LTranslit=/} (@misc);
        }
        # Check whether MISC contains gloss of the word form.
        my @gloss = map {my $x = $_; $x =~ s/^Gloss=//; $x} (grep {m/^Gloss=(.+)$/} (@misc));
        if (scalar(@gloss) > 0)
        {
            $node->set_gloss($gloss[0]);
            @misc = grep {!m/^Gloss=/} (@misc);
        }
        # Remaining MISC attributes (those that we don't have special fields for) will be stored as wild attributes.
        $node->set_misc(@misc);
    }
}



#------------------------------------------------------------------------------
# Takes the information we have collected about the enhanced graph and stores
# it as wild attributes.
#------------------------------------------------------------------------------
sub store_enhanced_graph
{
    my $self = shift;
    my $bundle = shift; # reference to the current bundle; needed only for the old implementation
    my $nodes = shift; # array reference; basic tree nodes (descendants of a-root, ordered)
    my $egraph = shift; # hash reference; information about enhanced relations
    my $empty_nodes = shift; # array reference; information about empty nodes (their word form and other attributes if available)
    log_fatal("Cannot store enhanced graph if there are no basic nodes.") if(scalar(@{$nodes})==0); ###!!! in fact, the new implementation needs the root but otherwise there could be only empty nodes
    my $root = $nodes->[0]->get_root();
    foreach my $enode (@{$empty_nodes})
    {
        my $node = $root->create_empty_node($enode->{id});
        $self->store_node_attributes($node, $enode->{form}, $enode->{lemma}, $enode->{upos}, $enode->{xpos}, $enode->{feats}); ###!!! a co MISC?
        if(defined($enode->{misc}) && $enode->{misc} ne '_')
        {
            # Store specific (expected) MISC attributes to dedicated node attributes.
            # Store all other MISC attributes as wild attributes.
            $self->store_misc_attributes($node, $enode->{misc});
        }
        push(@{$nodes}, $node);
    }
    foreach my $node (@{$nodes})
    {
        my $id = $node->get_conllu_id();
        # %{$egraph} already knows the @edeps array for each child node id.
        # We could have stored it with the nodes at the time we created them
        # but we postponed it because of the old implementation, which needed
        # to collapse empty-node paths after the whole graph became known.
        if(defined($egraph->{$id}))
        {
            $node->wild()->{enhanced} = $egraph->{$id};
        }
    }
}



#------------------------------------------------------------------------------
# Takes the information we have collected about the enhanced graph and stores
# it as wild attributes.
#
# This is the old and deprecated implementation that does not create Node
# objects for empty nodes and instead collapses paths that go through empty
# nodes into edges with special relation labels.
#------------------------------------------------------------------------------
sub store_enhanced_graph_old
{
    my $self = shift;
    my $bundle = shift; # reference to the current bundle
    my $nodes = shift; # array reference; basic tree nodes (descendants of a-root, ordered)
    my $egraph = shift; # hash reference; information about enhanced relations
    my $empty_nodes = shift; # array reference; information about empty nodes (their word form and other attributes if available)
    # Process the enhanced graph. We do not have objects for empty nodes.
    # Instead, we encode the path from the first non-empty ancestor as one
    # relation.
    my @cegraph = $self->collapse_enhanced_graph(%{$egraph});
    foreach my $node (@{$nodes})
    {
        my $id = $node->ord();
        my @edeps;
        my @pids = sort {$a <=> $b} (keys(%{$cegraph[$id]}));
        foreach my $pid (@pids)
        {
            my @deprels = sort {$a cmp $b} (keys(%{$cegraph[$id]{$pid}}));
            foreach my $deprel (@deprels)
            {
                push(@edeps, [$pid, $deprel]);
            }
        }
        $node->wild()->{enhanced} = \@edeps;
    }
    if(scalar(@{$empty_nodes}) > 0)
    {
        $bundle->wild->{empty_nodes} = $empty_nodes;
    }
}



#------------------------------------------------------------------------------
# Processes the enhanced graph. We do not have objects for empty nodes.
# Instead, we encode the path from the first non-empty ancestor as one
# relation.
#------------------------------------------------------------------------------
sub collapse_enhanced_graph
{
    my $self = shift;
    my %egraph = @_;
    my @ids = keys(%egraph);
    my @edges;
    foreach my $cid (@ids)
    {
        my @edeps = @{$egraph{$cid}};
        foreach my $edep (@edeps)
        {
            my $pid = $edep->[0];
            my $deprel = $edep->[1];
            push(@edges, [$pid, $deprel, $cid]);
        }
    }
    my @okedges = grep {$_->[0] =~ m/^\d+$/ && $_->[-1] =~ m/^\d+$/} (@edges);
    my @epedges = grep {$_->[0] =~ m/^\d+\.\d+$/} (@edges); # including those that have also empty child
    my @ecedges = grep {$_->[-1] =~ m/^\d+\.\d+$/} (@edges); # including those that have also empty parent
    while(@epedges)
    {
        my $epedge = shift(@epedges);
        my @myecedges = grep {$_->[-1] eq $epedge->[0]} (@ecedges);
        foreach my $ecedge (@myecedges)
        {
            my @newedge = @{$ecedge};
            pop(@newedge);
            push(@newedge, @{$epedge});
            # If there are cycles involving the empty nodes, ignore them.
            my $cycle = 0;
            my %map;
            for(my $i = 0; $i <= $#newedge; $i += 2)
            {
                if(exists($map{$newedge[$i]}))
                {
                    $cycle = 1;
                    last;
                }
                $map{$newedge[$i]}++;
            }
            unless($cycle)
            {
                if($newedge[0] =~ m/^\d+$/ && $newedge[-1] =~ m/^\d+$/)
                {
                    push(@okedges, \@newedge);
                }
                else
                {
                    if($newedge[0] =~ m/^\d+\.\d+$/)
                    {
                        push(@epedges, \@newedge);
                    }
                    if($newedge[-1] =~ m/^\d+\.\d+$/)
                    {
                        push(@ecedges, \@newedge);
                    }
                }
            }
            else
            {
                log_warn('Ignoring enhanced path '.join('>', @newedge));
            }
        }
    }
    # Now there are no more @epedges (while @ecedges grew over time but we do not care now).
    # All edges in @okedges have non-empty ends.
    @okedges = sort {my $r = $a->[-1] <=> $b->[-1]; unless($r) {$r = $a->[0] <=> $b->[0]} $r} (@okedges);
    my @cegraph;
    foreach my $edge (@okedges)
    {
        my @edge = @{$edge};
        my $pid = shift(@edge);
        my $cid = pop(@edge);
        my $deprel = join('>', @edge);
        # Avoid duplicate edges.
        $cegraph[$cid]{$pid}{$deprel}++;
    }
    return @cegraph;
}



1;

__END__

=head1 NAME

Treex::Block::Read::CoNLLU - read CoNLL-U format.

=head1 DESCRIPTION

Document reader for CoNLL-U format for Universal Dependencies.

See L<http://universaldependencies.github.io/docs/format.html>.

=head1 ATTRIBUTES

=over

=item from

space or comma separated list of filenames

=item lines_per_doc

number of sentences (!) per document

=back

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 SEE

L<Treex::Block::Read::BaseTextReader>
L<Treex::Core::Document>
L<Treex::Core::Bundle>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>,
Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015, 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
