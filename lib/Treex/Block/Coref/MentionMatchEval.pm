package Treex::Block::Coref::MentionMatchEval;
use Moose;
use List::MoreUtils qw/any/;
use Treex::Core::Common;
use Treex::Tool::Coreference::Utils;
use Treex::Tool::Coreference::NodeFilter;

extends 'Treex::Block::Write::BaseTextWriter';

has 'gold_selector' => ( is => 'ro', isa => 'Str', default => 'ref' );
has 'pred_selector' => ( is => 'ro', isa => 'Str', default => 'src' );
has '+extension' => ( default => '.tsv' );

has '_src_mentions' => ( is => 'rw', isa => 'HashRef' );
has '_ref_mentions' => ( is => 'rw', isa => 'HashRef' );

before 'process_document' => sub {
    my ($self, $doc) = @_;
    $self->_set_ref_mentions($self->all_mentions($doc, $self->gold_selector));
    $self->_set_src_mentions($self->all_mentions($doc, $self->pred_selector));
};

sub all_mentions {
    my ($self, $doc, $selector) = @_;
    my @ttrees = map {$_->get_tree($self->language, 't', $selector)} $doc->get_bundles;
    my @chains = Treex::Tool::Coreference::Utils::get_coreference_entities(\@ttrees);
    my @mentions = map {@$_} @chains;
    my %mentions_hash = map {$_->id => $_} @mentions;
    return \%mentions_hash;
}

sub process_bundle {
    my ($self, $bundle) = @_;
    
    my $ref_ttree = $bundle->get_tree($self->language, 't', $self->gold_selector);
    my $src_ttree = $bundle->get_tree($self->language, 't', $self->pred_selector);
    
    my %covered_src_nodes = ();
    foreach my $ref_tnode ($ref_ttree->get_descendants({ordered => 1})) {
        my $is_ref = $self->_ref_mentions->{$ref_tnode->id} ? 1 : 0;
        my ($ali_nodes, $ali_types) = $ref_tnode->get_undirected_aligned_nodes({language => $self->language, selector => $self->pred_selector});
        for (my $i = 0; $i < @$ali_nodes; $i++) {
            my $ali_src_tnode = $ali_nodes->[$i];
            $covered_src_nodes{$ali_src_tnode->id}++;
            my $is_src = $self->_src_mentions->{$ali_src_tnode->id} ? 1 : 0;
            my $is_both = ($is_ref && $is_src) ? 1 : 0;
            print {$self->_file_handle} $self->get_instance_str($is_ref, $is_src, $is_both, $ref_tnode, $ali_src_tnode);
        }
        if (!@$ali_nodes) {
            #printf STDERR "NO SRC: %s %d\n", $ref_tnode->get_address, 1-$gold_eval_class;
            print {$self->_file_handle} $self->get_instance_str($is_ref, 0, 0, $ref_tnode, undef);
        }
    }
    foreach my $src_tnode ($src_ttree->get_descendants({ordered => 1})) {
        next if (defined $covered_src_nodes{$src_tnode->id});
        my $is_src = $self->_src_mentions->{$src_tnode->id} ? 1 : 0;
        print {$self->_file_handle} $self->get_instance_str(0, $is_src, 0, undef, $src_tnode);
    }
}

sub all_aligned_zones {
    my ($self, $node) = @_;
    my ($ns, $ts) = $node->get_undirected_aligned_nodes;
    my @labels = map {my $n = $ns->[$_]; my $t = $ts->[$_]; $n->get_zone->get_label.":".$t} 0..$#$ns;
    return @labels;
}

sub get_instance_str {
    my ($self, $is_ref, $is_src, $is_both, $ref_tnode, $src_tnode) = @_;
    my $main_tnode = $ref_tnode // $src_tnode;
    my $str = join " ", (
        $is_ref,
        $is_src,
        $is_both,
        $ref_tnode->get_address,
        (join ",", Treex::Tool::Coreference::NodeFilter::get_types($main_tnode)),
        (defined $src_tnode ? join ",", $self->all_aligned_zones($src_tnode) : ""),
    );
    $str .= "\n";
    return $str;
}

1;

=head1 NAME

Treex::Block::Coref::MentionMatchEval

=head1 DESCRIPTION

Precision, recall and F-measure of mention matching.

=head1 SYNOPSIS

cd ~/projects/czeng_coref
treex -L cs 
    Read::Treex from=@data/cs/analysed/pdt/eval/0001/list 
    Util::SetGlobal selector=src 
    Coref::RemoveLinks type=all 
    A2T::CS::MarkRelClauseHeads 
    A2T::CS::MarkRelClauseCoref 
    Util::SetGlobal selector=ref 
    Coref::SimpleEval node_types='relpron,perspron'
| \$MLYN_DIR/scripts/eval.pl --prf --acc

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2018 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
