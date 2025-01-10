package Treex::Block::A2A::CorefClusters;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Coreference::Cluster;
extends 'Treex::Core::Block';



has last_document_id => (is => 'rw', default => '');
has last_cluster_id  => (is => 'rw', default => 0);



sub process_anode
{
    my $self = shift;
    my $anode = shift;
    my $last_cluster_id = $self->last_cluster_id();
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
        my $tnode = $anode->get_document()->get_node_by_id($tnode_rf);
        if(defined($tnode))
        {
            # Do we already have a cluster id?
            my $current_cluster_id = $anode->get_misc_attr('ClusterId');
            my $current_cluster_type = Treex::Tool::Coreference::Cluster::get_cluster_type($anode);
            # Get coreference edges.
            my ($cnodes, $ctypes) = $tnode->get_coref_nodes({'with_types' => 1});
            ###!!! Anja naznačovala, že pokud z jednoho uzlu vede více než jedna hrana gramatické koreference,
            ###!!! s jejich cíli by se nemělo nakládat jako s několika antecedenty, ale jako s jedním split antecedentem.
            ###!!! Gramatickou koreferenci poznáme tak, že má nedefinovaný typ entity.
            my $ng = scalar(grep {!defined($_)} (@{$ctypes}));
            if($ng >= 2)
            {
                log_warn("Grammatical coreference has $ng antecedents. Perhaps it should be one split antecedent.");
            }
            for(my $i = 0; $i <= $#{$cnodes}; $i++)
            {
                my $ctnode = $cnodes->[$i];
                my $ctype = $ctypes->[$i];
                # $ctnode is the target t-node of the coreference edge.
                # We need to access its corresponding lexical a-node.
                my $canode = $self->get_anode_for_tnode($ctnode);
                if(defined($canode))
                {
                    if(!defined($ctype) && $ng >= 2)
                    {
                        ###!!! Debugging: Mark instances of grammatical coreference with multiple antecedents.
                        Treex::Tool::Coreference::Cluster::add_mention_misc($canode, 'GramCorefSplitTo');
                        Treex::Tool::Coreference::Cluster::add_mention_misc($anode, 'GramCorefSplitFrom');
                    }
                    # Does the target node already have a cluster id and type?
                    my $current_target_cluster_id = $canode->get_misc_attr('ClusterId');
                    my $current_target_cluster_type = Treex::Tool::Coreference::Cluster::get_cluster_type($canode);
                    $current_cluster_type = $self->process_cluster_type($ctype, $current_cluster_type, $anode, $current_target_cluster_type, $canode);
                    if(defined($current_cluster_id) && defined($current_target_cluster_id))
                    {
                        # Are we merging two clusters that were created independently?
                        if($current_cluster_id ne $current_target_cluster_id)
                        {
                            # Merge the two clusters. Use the lower id. The higher id will remain unused.
                            Treex::Tool::Coreference::Cluster::merge_clusters($current_cluster_id, $anode, $current_target_cluster_id, $canode, $current_cluster_type);
                        }
                    }
                    elsif(defined($current_cluster_id))
                    {
                        # It is possible that the cluster does not have a type yet.
                        Treex::Tool::Coreference::Cluster::mark_cluster_type($anode, $current_cluster_type) if(defined($current_cluster_type));
                        Treex::Tool::Coreference::Cluster::add_nodes_to_cluster($current_cluster_id, $anode, $canode);
                    }
                    elsif(defined($current_target_cluster_id))
                    {
                        # It is possible that the cluster does not have a type yet.
                        Treex::Tool::Coreference::Cluster::mark_cluster_type($canode, $current_cluster_type) if(defined($current_cluster_type));
                        Treex::Tool::Coreference::Cluster::add_nodes_to_cluster($current_target_cluster_id, $canode, $anode);
                        $current_cluster_id = $current_target_cluster_id;
                    }
                    else
                    {
                        $current_cluster_id = Treex::Tool::Coreference::Cluster::create_cluster($self->get_new_cluster_id($anode), $current_cluster_type, $anode, $canode);
                    }
                }
                else
                {
                    log_warn("Target of coreference does not have a corresponding a-node.");
                }
            }
            # Get bridging edges.
            my ($bridgenodes, $bridgetypes) = $tnode->get_bridging_nodes();
            for(my $i = 0; $i <= $#{$bridgenodes}; $i++)
            {
                my $btnode = $bridgenodes->[$i];
                my $btype = $bridgetypes->[$i];
                # $btnode is the target t-node of the bridging edge.
                # We need to access its corresponding lexical a-node.
                my $banode = $self->get_anode_for_tnode($btnode);
                if(defined($banode))
                {
                    $self->mark_bridging($anode, $banode, $btype);
                }
                else
                {
                    log_warn("Target of bridging does not have a corresponding a-node.");
                }
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



#------------------------------------------------------------------------------
# Converts coreference cluster type, compares and merges it with the existing
# cluster type (if already known) of the coreferred nodes. Returns the type
# (we want to remember it as the current source node's cluster type).
#------------------------------------------------------------------------------
sub process_cluster_type
{
    my $self = shift;
    my $ctype = shift; # type from the current coreference edge (can be undef for grammatical coreference)
    my $srctype = shift; # type already marked on the source node (can be undef)
    my $srcnode = shift; # source node of the edge (needed only to mark errors)
    my $tgttype = shift; # type already marked on the target node (can be undef)
    my $tgtnode = shift; # target node of the edge (needed only to mark errors)
    if(defined($ctype))
    {
        if($ctype eq 'GEN')
        {
            # Generic entity, e.g., "úředníci".
            $ctype = 'gen';
        }
        elsif($ctype eq 'SPEC')
        {
            # Specific entity or event, e.g., "Václav Klaus".
            $ctype = 'spec';
        }
        else
        {
            log_warn("Unknown coreference cluster type '$ctype'.");
        }
    }
    # The type is undefined for grammatical coreference. We will
    # try to copy it from other members of the cluster if possible
    # (it is the type of the entity/event corresponding to the
    # cluster).
    else # !defined($ctype)
    {
        if(defined($srctype))
        {
            $ctype = $srctype;
        }
        elsif(defined($tgttype))
        {
            $ctype = $tgttype;
        }
    }
    # Sanity check: All coreference edges in a cluster should have the same type (or undefined type).
    if(defined($srctype) && defined($ctype) && $srctype ne $ctype)
    {
        log_warn("Cluster type mismatch.");
        # We may want to annotate the mismatch for debugging purposes but otherwise it should not appear in the final data.
        #Treex::Tool::Coreference::Cluster::add_mention_misc($srcnode, "ClusterTypeMismatch:$srctype:$ctype:1"); # :1 identifies where the error occurred in the source code
        # This mismatch is less likely than the other one below, as it would occur
        # between two coreference edges originating at the same source node. We
        # do not change $srctype, so the current edge will, too, use the previously
        # used cluster type.
        $ctype = $srctype;
    }
    if(!defined($srctype) && defined($ctype))
    {
        $srctype = $ctype;
    }
    # At this point we have unified $ctype and $srctype, and if it is undefined, then also $tgttype is undefined.
    # Sanity check: All coreference edges in a cluster should have the same type (or undefined type).
    if(defined($srctype) && defined($tgttype) && $srctype ne $tgttype)
    {
        log_warn("Cluster type mismatch.");
        # We may want to annotate the mismatch for debugging purposes but otherwise it should not appear in the final data.
        #Treex::Tool::Coreference::Cluster::add_mention_misc($srcnode, "ClusterTypeMismatch:$srctype:$tgttype:2"); # :2 identifies where the error occurred in the source code
        #Treex::Tool::Coreference::Cluster::add_mention_misc($tgtnode, "ClusterTypeMismatch:$srctype:$tgttype:2"); # :2 identifies where the error occurred in the source code
        # The conflict can be only between 'gen' and 'spec'. We will unify the type and give priority to 'gen'
        # (Anja says that the annotators looked specifically for 'gen', then batch-annotated everything else as 'spec').
        # Mark the new type at all nodes that are already in the cluster. We were called before the new coreference link is added,
        # so we do this for both nodes and both partial clusters.
        Treex::Tool::Coreference::Cluster::mark_cluster_type($srcnode, 'gen');
        Treex::Tool::Coreference::Cluster::mark_cluster_type($tgtnode, 'gen');
        $srctype = $tgttype = $ctype = 'gen';
    }
    # If the target subcluster did not have a type until now, and we have a type now, propagate it there.
    if(defined($srctype) && defined($tgtnode) && !defined($tgttype))
    {
        Treex::Tool::Coreference::Cluster::mark_cluster_type($tgtnode, $srctype);
    }
    return $srctype;
}



#------------------------------------------------------------------------------
# Saves a bridging relation between two nodes in their misc attributes.
#------------------------------------------------------------------------------
sub mark_bridging
{
    my $self = shift;
    my $srcnode = shift;
    my $tgtnode = shift;
    my $btype = shift;
    if($btype eq 'WHOLE_PART')
    {
        # kraje <-- obce
        $btype = 'part';
    }
    elsif($btype eq 'PART_WHOLE')
    {
        $btype = 'part';
        my $x = $srcnode;
        $srcnode = $tgtnode;
        $tgtnode = $x;
    }
    elsif($btype eq 'SET_SUB')
    {
        # veřejní činitelé <-- poslanci
        # poslanci <-- konkrétní poslanec
        $btype = 'subset';
    }
    elsif($btype eq 'SUB_SET')
    {
        $btype = 'subset';
        my $x = $srcnode;
        $srcnode = $tgtnode;
        $tgtnode = $x;
    }
    elsif($btype eq 'P_FUNCT')
    {
        # obě dvě ministerstva <-- ministři kultury a financí | Pavel Tigrid a Ivan Kočárník
        $btype = 'funct';
    }
    elsif($btype eq 'FUNCT_P')
    {
        $btype = 'funct';
        my $x = $srcnode;
        $srcnode = $tgtnode;
        $tgtnode = $x;
    }
    elsif($btype eq 'ANAF')
    {
        # "loterie mohou provozovat pouze organizace k tomu účelu zvláště zřízené" <-- uvedená pasáž
        $btype = 'anaf';
    }
    elsif($btype eq 'REST')
    {
        $btype = 'other';
    }
    elsif($btype =~ m/^(CONTRAST)$/)
    {
        # This type is not really bridging (it holds between two mentions rather than two clusters).
        # We ignore it.
        return;
    }
    else
    {
        log_warn("Unknown bridging relation type '$btype'.");
    }
    # Do the source and the target node already have cluster ids?
    my $current_source_cluster_id = $srcnode->get_misc_attr('ClusterId');
    my $current_target_cluster_id = $tgtnode->get_misc_attr('ClusterId');
    # If the target cluster already exists, it must not contain the source node
    # (identity coreference excludes bridging). This happens at least once in
    # PDT-C 2.0 and from our perspective it is an error (https://github.com/ufal/PDT-C/issues/7).
    # We must catch it now, otherwise it will be a fatal error later on.
    if(defined($current_target_cluster_id))
    {
        my $current_target_members = $tgtnode->wild()->{cluster_members};
        if(defined($current_target_members) && ref($current_target_members) eq 'ARRAY')
        {
            if(any {$_ eq $srcnode->id()} (@{$current_target_members}))
            {
                # The source node of bridging is already member of the target
                # cluster. We cannot accept such a bridging relation.
                my $srcid = $srcnode->id();
                my $srcform = $srcnode->form() // '';
                my $tgtids = join(', ', @{$current_target_members});
                log_warn("Ignoring '$btype' bridging where the source node ($srcid '$srcform') is already member of the target cluster ($tgtids).");
                return;
            }
        }
    }
    # We need a cluster id for the source node even if the cluster will be
    # a singleton because bridging is defined as a relation between clusters.
    if(!defined($current_source_cluster_id))
    {
        $current_source_cluster_id = Treex::Tool::Coreference::Cluster::create_cluster($self->get_new_cluster_id($srcnode), undef, $srcnode);
    }
    # Similarly, if the target node is not yet in a cluster, we must create it.
    if(!defined($current_target_cluster_id))
    {
        $current_target_cluster_id = Treex::Tool::Coreference::Cluster::create_cluster($self->get_new_cluster_id($tgtnode), undef, $tgtnode);
    }
    # Does the source node already have other bridging relations?
    my $bridging = $srcnode->get_misc_attr('Bridging');
    my @bridging = ();
    @bridging = split(/,/, $bridging) if(defined($bridging));
    push(@bridging, "$current_target_cluster_id:$btype");
    if(scalar(@bridging) > 0)
    {
        @bridging = Treex::Tool::Coreference::Cluster::sort_bridging(@bridging);
        $srcnode->set_misc_attr('Bridging', join(',', @bridging));
        Treex::Tool::Coreference::Cluster::add_bridging_to_cluster($tgtnode, $srcnode);
    }
}



#------------------------------------------------------------------------------
# Returns the next available cluster id for the current document.
#------------------------------------------------------------------------------
sub get_new_cluster_id
{
    my $self = shift;
    my $node = shift; # we need a node to be able to access the bundle
    # We need a new cluster id.
    # In released data, the ClusterId should be just 'c' + natural number.
    # However, larger unique strings are allowed during intermediate stages,
    # and we need them in order to ensure uniqueness across multiple documents
    # in one file. Clusters never span multiple documents, so we will insert
    # the document id. Since Treex documents do not have an id attribute, we
    # will assume that a prefix of the bundle id uniquely identifies the document.
    my $docid = $node->get_bundle()->id();
    # In PDT, remove trailing '-p1s1' (paragraph and sentence number).
    # In PCEDT, remove trailing '-s1' (there are no paragraph boundaries).
    $docid =~ s/-(p[0-9A-Z]+)?s[0-9A-Z]+$//;
    # Certain characters cannot be used in cluster ids because they are used
    # as delimiters in the coreference annotation.
    $docid =~ s/[-|=:,+\s]//g;
    my $last_document_id = $self->last_document_id();
    my $last_cluster_id = $self->last_cluster_id();
    if($docid ne $last_document_id)
    {
        $last_document_id = $docid;
        $self->set_last_document_id($last_document_id);
        $last_cluster_id = 0;
    }
    $last_cluster_id++;
    $self->set_last_cluster_id($last_cluster_id);
    my $id = $docid.'c'.$last_cluster_id;
    return $id;
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
