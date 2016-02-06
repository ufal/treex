package Treex::Block::Align::Annot::Print;

use Moose;
use Moose::Util 'apply_all_roles';
use Treex::Core::Common;

extends 'Treex::Block::Write::BaseTextWriter';
# Applied at runtime:
# with 'Treex::Block::Filter::Node' => { layer => $self->layer };

has 'layer' => ( is => 'ro', isa => 'Str', default => 't' );
has 'aligns' => ( is => 'ro', isa => 'Str', required => 1 );

has '_aligns_graph' => ( is => 'ro', isa => 'HashRef', builder => '_build_aligns_graph', lazy => 1 );

sub BUILD {
    my ($self) = @_;
    apply_all_roles( 
        $self,
        'Treex::Block::Filter::Node' => { layer => $self->layer },
    );
    $self->_aligns_graph;
}

sub _build_node_types {
    return 'all_anaph';
}

sub _build_aligns_graph {
    my ($self) = @_;
    my @align_pairs = split /;/, $self->aligns;
    my $aligns_graph = {};
    foreach my $align_pair (@align_pairs) {
        my ($l1, $l2, $type) = split /[-:]/, $align_pair;
        $aligns_graph->{$l1}{$l2} = $type;
        $aligns_graph->{$l2}{$l1} = $type;
    }
    return $aligns_graph;
}

# returns a HashRef with all languages as its keys and lists of aligned nodes as the values
# the method requires that alignment links form a path over all languages => each language
# is aligned with at most two other languages - these alignemnts must be specified in the
# <$aligns> parameter
sub _aligned_nodes {
    my ($self, $node) = @_;
    my $aligned_nodes = {
        $self->language => [ $node ],
    };
    my %aligns_graph = %{$self->_aligns_graph};
    my @lang_queue = ( $self->language );
    while (my $l1 = shift @lang_queue) {
        my $aligned_to_lang = $aligns_graph{$l1} // {};
        foreach my $l2 (keys %$aligned_to_lang) {
            my @rel_types = split /,/, $aligned_to_lang->{$l2};
            my @all_ali_nodes = map { 
                my ($ali_nodes, $ali_types) = $_->get_undirected_aligned_nodes({
                    language => $l2, 
                    selector => $_->selector, 
                    rel_types => \@rel_types
                });
                @$ali_nodes
            } @{$aligned_nodes->{$l1}};
            $aligned_nodes->{$l2} = \@all_ali_nodes;
            push @lang_queue, $l2;
            delete $aligns_graph{$l1}{$l2};
            delete $aligns_graph{$l2}{$l1};
        }
    }
}

sub _process_node {
    my ($self, $node) = @_;

    my $nodes = $self->_aligned_nodes($node);
    my @langs = ($self->language, sort grep {$_ ne $self->language} keys %$nodes);
    my @zones = map {$node->get_bundle->get_zone($_, $self->selector)} @langs;

    print {$self->_file_handle} "ID: " . $node->get_address . "\n";
    
    if ($self->layer eq "a") {
        for (my $i = 0; $i < @langs; $i++) {
            print {$self->_file_handle} uc($langs[$i])."_A:\t" . _linearize_atree($zones[$i], $nodes->{$langs[$i]}) . "\n";
        }
    }
    else {
        for (my $i = 0; $i < @langs; $i++) {
            print {$self->_file_handle} uc($langs[$i]).":\t" . $zones[$i]->sentence . "\n";
        }
        for (my $i = 0; $i < @langs; $i++) {
            print {$self->_file_handle} uc($langs[$i])."_T:\t" . _linearize_ttree_structured($zones[$i], $nodes->{$langs[$i]}) . "\n";
        }
    }

    for (my $i = 1; $i < @langs; $i++) {
        print {$self->_file_handle} "INFO_".uc($langs[$i]).":\t\n";
    }
    print {$self->_file_handle} "\n";
}


sub process_filtered_tnode {
    my ($self, $tnode) = @_;
    $self->_process_node($tnode);
}

sub process_filtered_anode {
    my ($self, $anode) = @_;
    print "NODE_TYPES: " . Dumper($self->node_types);
    $self->_process_node($anode);
}

sub _linearize_atree {
    my ($zone, $on_nodes) = @_;

    my %on_nodes_indic = map {$_->id => 1} @$on_nodes;

    my @tree_nodes = $zone->get_atree->get_descendants({ordered => 1});
    my @tree_forms = map {
        $on_nodes_indic{$_->id} ? "<" . $_->form . ">" : $_->form;
    } @tree_nodes;

    return join " ", @tree_forms;
}

sub _linearize_tnode {
    my ($tnode, $highlight_indic) = @_;
   
    my $word = "";
    
    my $anode = $tnode->get_lex_anode;
    if (defined $anode) {
        $word = $anode->form;
    }
    else {
        $word = $tnode->t_lemma .".". $tnode->functor;
    }
    $word =~ s/ /_/g;
    $word =~ s/</&lt;/g;
    $word =~ s/>/&gt;/g;
    $word =~ s/\[/&osb;/g;
    $word =~ s/\]/&csb;/g;

    if ($highlight_indic->{$tnode->id}) {
        $word = "<" . $word . ">";
    }
    my @hl_anodes = grep {$_->get_layer eq "a"} values %$highlight_indic;
    my ($hl_anode_idx) = grep {
        my ($hl_tnode) = $hl_anodes[$_]->get_referencing_nodes('a/aux.rf');
        defined $hl_tnode && $hl_tnode == $tnode
    } 0 .. $#hl_anodes;
    if (defined $hl_anode_idx) {
        $word = "<__A:". $hl_anodes[$hl_anode_idx]->id ."__". $word . ">";
    }
    return $word;
}

sub _linearize_ttree {
    my ($ttree, $highlight_arr) = @_;

    my $highlight_indic = { map {$_->id => $_} grep {defined $_} @$highlight_arr };

    my @words = map {_linearize_tnode($_, $highlight_indic)} $ttree->get_descendants({ordered => 1});
    return join " ", @words;
}

sub _linearize_ttree_structured {
    my ($ttree, $highlight_arr) = @_;
    
    my $highlight_indic = { map {$_->id => $_} grep {defined $_} @$highlight_arr };

    my ($sub_root) = $ttree->get_children({ordered => 1});
    my $str = _linearize_subtree_recur($sub_root, $highlight_indic);
    return $str;
}

sub _linearize_subtree_recur {
    my ($subtree, $highlight_indic) = @_;
    
    my $str = _linearize_tnode($subtree, $highlight_indic);
    my @childs = $subtree->get_children({ordered => 1});
    if (@childs) {
        $str .= " [ ";
        my @child_strs = map {_linearize_subtree_recur($_, $highlight_indic)} @childs;
        $str .= join " ", @child_strs;
        $str .= " ]";
    }
    return $str;
}

1;

__END__

=head1 NAME

Treex::Block::Align::Annot::Print;

=head1 DESCRIPTION


=head1 PARAMETERS

=over

=item node_types

A comma-separated list of the node types on which this block should be applied.
See C<Treex::Tool::Coreference::NodeFilter> for possible values.

=head1 AUTHOR

Michal Novak <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015-16 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
