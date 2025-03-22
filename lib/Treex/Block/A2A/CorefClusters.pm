package Treex::Block::A2A::CorefClusters;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Core::EntitySet;
extends 'Treex::Core::Block';



has last_document_id => (is => 'rw', default => '');
has last_cluster_id  => (is => 'rw', default => 0);



sub process_anode
{
    my $self = shift;
    my $anode = shift;
    my $last_cluster_id = $self->last_cluster_id();
    # Get the document-wide collection of entities. If it does not exist yet,
    # create it. We want it to exist even if the current document contains no
    # coreference links. If someone used this block, they may want to use others
    # that rely on the EntitySet, even if it is empty.
    my $document = $anode->get_document();
    if(!exists($document->wild()->{eset}))
    {
        $document->wild()->{eset} = new Treex::Core::EntitySet();
    }
    my $eset = $document->wild()->{eset};
    ###!!! In a few cases, annotation errors in PDT cause validity problems later in CorefUD.
    ###!!! Ideally we should fix the source annotation but that is out of our reach at present.
    ###!!! So, instead, we hard-code ids of nodes whose coreference links should be ignored.
    my $sentid = $anode->get_bundle()->id();
    if(
        # Rozdílný vývoj v ČR a SR rok po rozpadu ČSFR *
        # ČR a SR jsou anotovány jako koreferenční (!), dvě překrývající se zmínky entity cmpr9413012c1 jsou "v ČR" a "v SR".
        $sentid eq 'cmpr9413-012-p3s1A' && $anode->form() eq 'SR' ||
        # na mezinárodních konferencích v Bukurešti v roce 1974 a Mexico City v roce 1984
        # "konference" je na t-rovině zduplikována, jenže pak je označena koreference mezi mexickou a bukurešťskou konferencí!
        # K tomu je problém s chybnou anotací syntaxe na analytické rovině.
        $sentid eq 'ln94208-79-p7s1' && $anode->is_empty() && defined($anode->lemma()) && $anode->lemma() eq 'konference'
    )
    {
        return;
    }
    # Only nodes linked to t-layer can have coreference annotation.
    if(exists($anode->wild()->{'tnode.rf'}))
    {
        my $tnode_rf = $anode->wild()->{'tnode.rf'};
        my $tnode = $document->get_node_by_id($tnode_rf);
        if(defined($tnode))
        {
            # We do not want to create a mention around this node now if we do
            # not know about outgoing coreference or bridging links. (The node
            # may still become a mention if there are incoming coreference or
            # bridging links.)
            ###!!! This should be implemented better. Because we now get the
            ###!!! links and later will get them again for the actual processing.
            my ($cnodes, $ctypes) = $tnode->get_coref_nodes({'with_types' => 1});
            my ($bridgenodes, $bridgetypes) = $tnode->get_bridging_nodes();
            if(scalar(@{$cnodes}) > 0 || scalar(@{$bridgenodes}) > 0)
            {
                my $mention = $eset->get_or_create_mention_for_thead($tnode);
                $mention->process_coreference();
                $mention->process_bridging();
            }
        }
    }
}



#------------------------------------------------------------------------------
# Finds a corresponding a-node for a given t-node. For non-generated t-nodes,
# this is their lexical a-node via the standard reference from the t-layer.
# For generated t-nodes we have created empty a-nodes in the block T2A::
# GenerateEmptyNodes; the reference to such a node is stored in a wild
# attribute.
#------------------------------------------------------------------------------
sub get_anode_for_tnode
{
    my $self = shift;
    my $tnode = shift;
    my $anode;
    if($tnode->is_generated())
    {
        if(exists($tnode->wild()->{'anode.rf'}))
        {
            $anode = $tnode->get_document()->get_node_by_id($tnode->wild()->{'anode.rf'});
        }
        else
        {
            log_warn("Generated t-node does not have a wild reference to a corresponding empty a-node.");
        }
    }
    else
    {
        $anode = $tnode->get_lex_anode();
    }
    return $anode;
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CorefClusters

=item DESCRIPTION

Processes UD a-nodes that are linked to t-nodes (some of the a-nodes model
empty nodes in enhanced UD and may be linked to generated t-nodes). Scans
coreference links and assigns a unique cluster id to all nodes participating
on one coreference cluster. Saves the cluster id as a MISC (wild) attribute.

=head1 AUTHORS

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2021, 2025 by Institute of Formal and Applied Linguistics, Charles University, Prague.

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
