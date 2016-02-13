package Treex::Block::Align::Annot::Print;

use Moose;
use Treex::Core::Common;
use List::MoreUtils qw/all any/;
use Moose::Util::TypeConstraints;

use Treex::Tool::Align::Annot::Util;

extends 'Treex::Block::Write::BaseTextWriter';
with 'Treex::Block::Filter::Node';

subtype 'LangsArrayRef' => as 'ArrayRef';
coerce 'LangsArrayRef'
    => from 'Str'
    => via { [split /,/] };

has 'align_langs' => ( is => 'ro', isa => 'LangsArrayRef', coerce => 1, required => 1 );
has 'gold_ali_type' => ( is => 'ro', isa => 'Str', default => 'gold' );
#
#has 'aligns' => ( is => 'ro', isa => 'Str', required => 1 );
#has '_aligns_graph' => ( is => 'ro', isa => 'HashRef', builder => '_build_aligns_graph', lazy => 1 );
#
#sub BUILD {
#    my ($self) = @_;
#    $self->_aligns_graph;
#}
#
#sub _build_aligns_graph {
#    my ($self) = @_;
#    my @align_pairs = split /;/, $self->aligns;
#    my $aligns_graph = {};
#    foreach my $align_pair (@align_pairs) {
#        my ($langs, $type) = split /:/, $align_pair, 2;
#        my ($l1, $l2) = split /-/, $langs, 2;
#        $aligns_graph->{$l1}{$l2} = $type;
#        $aligns_graph->{$l2}{$l1} = $type;
#    }
#    return $aligns_graph;
#}

sub _build_node_types {
    return 'all_anaph';
}

# print only for t-nodes by default
sub _build_layers {
    return "t";
}

sub get_giza_aligns {
    my ($self, $node, $gold_aligns) = @_;

    my $start_list = [ $node ];
    my $giza_aligns = { $node->language => $start_list };
    my @queue = ( $start_list );
    my @other_langs = grep {!defined $giza_aligns->{$_}} sort keys %$gold_aligns;

    while (@other_langs && @queue) {
        my $curr_list = shift @queue;
        foreach my $lang (@other_langs) {
            my @lang_list = map {
                my ($ali_nodes, $ali_types) = $node->get_undirected_aligned_nodes({ 
                    language => $lang, 
                    selector => $node->selector,
                    # every type except for the 'gold'
                    rel_types => ["!".$self->gold_ali_type, ".*"],
                });
                @$ali_nodes;
            } @$curr_list;
            $giza_aligns->{$lang} = \@lang_list;
            push @queue, \@lang_list if (@lang_list);
        }
        @other_langs = grep {!defined $giza_aligns->{$_}} sort keys %$gold_aligns;
    }
    return $giza_aligns;
}

sub process_filtered_anode {
    my ($self, $anode) = @_;
    $self->_print_for_layer_node($anode, 'a');
}
sub process_filtered_tnode {
    my ($self, $tnode) = @_;
    $self->_print_for_layer_node($tnode, 't');
}

sub _print_for_layer_node {
    my ($self, $node, $layer) = @_;

    my $gold_aligns = Treex::Tool::Align::Annot::Util::get_gold_aligns($node, $self->align_langs, $self->gold_ali_type);
    my $align_info = Treex::Tool::Align::Annot::Util::get_align_info($gold_aligns);
    
    # from collected align_info find out how many languages are covered
    return if (scalar keys %$gold_aligns == scalar keys %$align_info);
    
    my $giza_aligns = $self->get_giza_aligns($node, $gold_aligns);
    my %merged_aligns = map {$_ => ( defined $align_info->{$_} ? $gold_aligns->{$_} : ($giza_aligns->{$_} // []))} keys %$gold_aligns;

    my @langs = ($self->language, sort grep {$_ ne $self->language} keys %merged_aligns);
    my @zones = map {$node->get_bundle->get_zone($_, $self->selector)} @langs;

    print {$self->_file_handle} "ID: " . $node->get_address . "\n";

    if ($layer eq 'a') {
        $self->print_sentences_anodes(\%merged_aligns, \@langs, \@zones);
    }
    else {
        $self->print_sentences_tnodes(\%merged_aligns, \@langs, \@zones);
    }

    foreach my $lang (@langs) {
        printf {$self->_file_handle} "INFO_%s:\t%s\n", uc($lang), $align_info->{$lang} // "";
    }
    print {$self->_file_handle} "\n";
}

sub print_sentences_anodes {
    my ($self, $nodes, $langs, $zones) = @_;

    for (my $i = 0; $i < @$langs; $i++) {
        print {$self->_file_handle} uc($langs->[$i])."_A:\t" . _linearize_atree($zones->[$i], $nodes->{$langs->[$i]}) . "\n";
    }
}

sub print_sentences_tnodes {
    my ($self, $nodes, $langs, $zones) = @_;

    for (my $i = 0; $i < @$langs; $i++) {
        print {$self->_file_handle} uc($langs->[$i]).":\t" . $zones->[$i]->sentence . "\n";
    }
    for (my $i = 0; $i < @$langs; $i++) {
        print {$self->_file_handle} uc($langs->[$i])."_T:\t" . _linearize_ttree_structured($zones->[$i], $nodes->{$langs->[$i]}) . "\n";
    }
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
