package Treex::Block::Align::T::Supervised::PrintData;

use Moose;
use Treex::Core::Common;

use Treex::Tool::ML::VowpalWabbit::Util;
use Treex::Tool::Align::Utils;

extends 'Treex::Block::Write::BaseTextWriter';
with 'Treex::Block::Align::T::Supervised::Base';
with 'Treex::Block::Filter::Node::T';

has 'gold_align_filter' => (is => 'ro', isa => 'HashRef', builder => '_build_gaf');

sub BUILD {
    my ($self) = @_;
    $self->gold_align_filter;
}

sub _build_gaf {
    my ($self) = @_;
    return { language => $self->align_language, rel_types => ['gold'] };
}


sub _get_positive_candidate {
    my ($self, $tnode) = @_;

    # TODO: My::ProjectAlignment has to be called upfront
    # better to put it here

    my ($gold_ali_node) = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [$self->gold_align_filter]);
    return $gold_ali_node // $tnode;
}

sub _get_losses {
    my ($cands, $pos_cand) = @_;

    my @losses = map {$cands->[$_] == $pos_cand ? 0 : 1} 0 .. $#$cands;
    return \@losses;
}

sub process_filtered_tnode {
    my ($self, $tnode) = @_;

    my @cands = $self->_get_candidates($tnode);
    my $feats = $self->_feat_extractor->create_instances($tnode, \@cands);
    
    my ($gold_aligned_node) = $self->_get_positive_candidate($tnode);
    #log_info "GOLD_ALIGNED_LEMMA: ". ($gold_aligned_node != $tnode ? $gold_aligned_node->t_lemma : "undef");
    my $losses = _get_losses(\@cands, $gold_aligned_node);
    #log_info "CAND_IDX: $pos_cand_idx";
    my @comments = map {$_->get_address()} @cands;

    my $instance_str = Treex::Tool::ML::VowpalWabbit::Util::format_multiline($feats, $losses, [ \@comments, "" ]);
    print {$self->_file_handle} $instance_str;
}

1;
