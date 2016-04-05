package Treex::Block::Coref::SupervisedBase;
use Moose::Role;
use Treex::Core::Common;

use Treex::Tool::Coreference::CorefFeatures;
use Treex::Tool::Coreference::AnteCandsGetter;

with 'Treex::Block::Filter::Node::T';

has 'anaphor_as_candidate' => (
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
    default  => 1,
    documentation => 'joint anaphoricity determination and antecedent selection',
);

has '_feature_extractor' => (
    is          => 'ro',
    required    => 1,
    lazy        => 1,
    isa         => 'Treex::Tool::Coreference::CorefFeatures',
    builder     => '_build_feature_extractor',
);
has '_ante_cands_selector' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Treex::Tool::Coreference::AnteCandsGetter',
    lazy        => 1,
    builder     => '_build_ante_cands_selector',
);

sub _build_node_types {
    my ($self) = @_;
    log_fatal "method _build_node_types must be overriden in " . ref($self);
}
sub _build_feature_extractor {
    my ($self) = @_;
    log_fatal "method _build_feature_extractor must be overriden in " . ref($self);
}
sub _build_ante_cands_selector {
    my ($self) = @_;
    log_fatal "method _build_ante_cands_selector must be overriden in " . ref($self);
}

sub get_features_comments {
    my ($self, $tnode, $cands) = @_;
    my $feats = $self->_feature_extractor->create_instances($tnode, $cands);
    my $comments = _comments_from_feats($feats);
    my $new_feats = _remove_id_feats($feats);
    return ($new_feats, $comments);
}

sub _comments_from_feats {
    my ($feats) = @_;
    my ($cand_feats, $shared_feats) = @$feats;
    my @cand_comments = map {_comment_for_line($_, "cand")} @$cand_feats;
    my $shared_comment = _comment_for_line($shared_feats, "anaph");
    return [\@cand_comments, $shared_comment];
}

sub _comment_for_line {
    my ($feat_list, $type) = @_;

    my %feat_hash = map {$_->[0] => $_->[1]} @$feat_list;
    my $id = $feat_hash{$type."_id"} // "";
    my $align_id = $feat_hash{"align_".$type."_id"} // "";
    my $comment = sprintf "%s %s", $id, $align_id;
    return $comment;
}

sub _remove_id_feats {
    my ($feats) = @_;
    my ($cand_feats, $shared_feats) = @$feats;
    my @cand_new_feats = map {_remove_id_feats_for_line($_)} @$cand_feats;
    my $shared_new_feats = _remove_id_feats_for_line($shared_feats);
    return [\@cand_new_feats, $shared_new_feats];
}

sub _remove_id_feats_for_line {
    my ($feat_list) = @_;
    my @filtered_feat_list = grep {$_->[0] !~ /_id$/} @$feat_list;
    return \@filtered_feat_list;
}

1;
#TODO extend documentation

__END__

=head1 NAME

Treex::Block::Coref::SupervisedBase

=head1 DESCRIPTION

This role is a basis for supervised coreference resolution.
Both the data printer and resolver should apply this role.

=head1 AUTHOR

Michal Novak <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
