package Treex::Block::T2A::GenerateEmptyNodes;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $troot = $zone->get_tree('t');
    my $aroot = $zone->get_tree('a');
    my @tnodes = $troot->get_descendants({ordered => 1});
    my @anodes = $aroot->get_descendants({ordered => 1});
    my $lastanode = $anodes[-1];
    my $major = $lastanode->ord();
    my $minor = 0;
    foreach my $tnode (@tnodes)
    {
        if($tnode->is_generated())
        {
            my $anode = $aroot->create_child();
            $anode->set_deprel('dep:empty');
            $anode->wild()->{'tnode.rf'} = $tnode->id();
            $anode->wild()->{enhanced} = [];
            $minor++;
            $anode->wild()->{enord} = "$major.$minor";
            $anode->shift_after_node($lastanode);
            $lastanode = $anode;
            $anode->set_form('_');
            $anode->set_lemma($tnode->t_lemma());
            # If the generated node is a copy of a real node, we may be able to
            # copy its attributes.
            my $source_anode = $tnode->get_lex_anode();
            if(defined($source_anode))
            {
                $anode->set_form($source_anode->form());
                $anode->set_tag($source_anode->tag());
                $anode->iset()->set_hash($source_anode->iset()->get_hash());
            }
            if($tnode->t_lemma() =~ m/^\#(PersPron|Gen|Q?Cor|Rcp)$/)
            {
                $anode->set_tag('PRON');
                $anode->iset()->set_hash({'pos' => 'noun', 'prontype' => 'prs'});
            }
            elsif($tnode->t_lemma() eq '#Neg')
            {
                $anode->set_tag('PART');
                $anode->iset()->set_hash({'pos' => 'part', 'polarity' => 'neg'});
            }
            else
            {
                $anode->set_tag('X');
            }
            # We need an enhanced relation to make the empty node connected with
            # the enhanced dependency graph. Try to propagate the dependency from
            # the t-tree.
            my $tparent = $tnode->parent();
            my $aparent = $tparent->get_lex_anode();
            # The $aparent may not exist or it may be in another sentence, in
            # which case we cannot use it.
            if(defined($aparent) && $aparent->get_root() == $aroot)
            {
                $self->add_enhanced_dependency($anode, $aparent, 'dep');
            }
        }
    }
}



#==============================================================================
# Helper functions for manipulation of the enhanced graph.
#==============================================================================



#------------------------------------------------------------------------------
# Returns the list of incoming enhanced edges for a node. Each element of the
# list is a pair: 1. ord of the parent node; 2. relation label.
#------------------------------------------------------------------------------
sub get_enhanced_deps
{
    my $self = shift;
    my $node = shift;
    my $wild = $node->wild();
    if(!exists($wild->{enhanced}) || !defined($wild->{enhanced}) || ref($wild->{enhanced}) ne 'ARRAY')
    {
        log_fatal("Wild attribute 'enhanced' does not exist or is not an array reference.");
    }
    return @{$wild->{enhanced}};
}



#------------------------------------------------------------------------------
# Adds a new enhanced edge incoming to a node, unless the same relation with
# the same parent already exists.
#------------------------------------------------------------------------------
sub add_enhanced_dependency
{
    my $self = shift;
    my $child = shift;
    my $parent = shift;
    my $deprel = shift;
    # Self-loops are not allowed in enhanced dependencies.
    # We could silently ignore the call but there is probably something wrong
    # at the caller's side, so we will throw an exception.
    if($parent == $child)
    {
        my $ord = $child->ord();
        my $form = $child->form() // '';
        log_fatal("Self-loops are not allowed in the enhanced graph but we are attempting to attach the node no. $ord ('$form') to itself.");
    }
    my $pord = $parent->ord();
    my @edeps = $self->get_enhanced_deps($child);
    unless(any {$_->[0] == $pord && $_->[1] eq $deprel} (@edeps))
    {
        push(@{$child->wild()->{enhanced}}, [$pord, $deprel]);
    }
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::GenerateEmptyNodes

=item DESCRIPTION

Generates an empty node (as in enhanced UD graphs, in the form recognized by
Write::CoNLLU) for every generated t-node, and stores in its wild attributes
a reference to the corresponding t-node (in the same fashion as GenerateA2TRefs
stores references from real a-nodes to corresponding t-nodes).

While it may be useful to run T2A::GenerateA2TRefs before the conversion from
Prague to UD (so that the conversion procedure has access to tectogrammatic
annotation), calling this block is better postponed until the basic UD tree is
ready. The empty nodes will participate only in enhanced dependencies, so they
are not needed earlier. But they are represented using fake a-nodes, which
might confuse the conversion functions that operate on the basic (a-)tree.

=head1 AUTHORS

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2021 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
