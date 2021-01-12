package Treex::Block::A2A::CorefClusters;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



has last_cluster_id => (is => 'rw', default => 0);



sub process_anode
{
    my $self = shift;
    my $anode = shift;
    my $last_cluster_id = $self->last_cluster_id();
    # Only nodes linked to t-layer can have coreference annotation.
    if(exists($anode->wild()->{'tnode.rf'}))
    {
        my $tnode_rf = $anode->wild()->{'tnode.rf'};
        my $tnode = $anode->get_document()->get_node_by_id($tnode_rf);
        if(defined($tnode))
        {
            # Do we already have a cluster id?
            my $current_cluster_id = $anode->get_misc_attr('ClusterId');
            # Get coreference edges.
            my @gcoref = $tnode->get_coref_gram_nodes();
            my @tcoref = $tnode->get_coref_text_nodes();
            foreach my $ctnode (@gcoref, @tcoref)
            {
                # $ctnode is the target t-node of the coreference edge.
                # We need to access its corresponding lexical a-node.
                my $canode = $ctnode->get_lex_anode();
                if(defined($canode))
                {
                    # Does the target node already have a cluster id?
                    my $current_target_cluster_id = $canode->get_misc_attr('ClusterId');
                    if(defined($current_cluster_id) && defined($current_target_cluster_id))
                    {
                        if($current_cluster_id != $current_target_cluster_id)
                        {
                            log_warn("Coreference between two nodes that already have two different cluster ids.");
                        }
                    }
                    elsif(defined($current_cluster_id))
                    {
                        $canode->set_misc_attr('ClusterId', $current_cluster_id);
                    }
                    elsif(defined($current_target_cluster_id))
                    {
                        $anode->set_misc_attr('ClusterId', $current_target_cluster_id);
                    }
                    else
                    {
                        # We need a new cluster id.
                        $last_cluster_id++;
                        $self->set_last_cluster_id($last_cluster_id);
                        $anode->set_misc_attr('ClusterId', $last_cluster_id);
                        $canode->set_misc_attr('ClusterId', $last_cluster_id);
                        $current_cluster_id = $last_cluster_id;
                    }
                }
            }
        }
    }
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

Copyright © 2021 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
