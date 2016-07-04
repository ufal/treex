package Treex::Tool::Coreference::Features::PersPron;

use Moose;
use Treex::Core::Common;
use List::MoreUtils qw/any/;

extends 'Treex::Tool::Coreference::BaseCorefFeatures';

my $UNDEF_VALUE = "undef";

augment '_unary_features' => sub {
    my ($self, $node, $type) = @_;

    my $feats = {};

    $feats->{'id'} = $node->get_address;

    $feats->{'tlemma'} = $node->t_lemma;
    $feats->{'fmm'} = $node->formeme;

    $feats->{'gen'} = $node->gram_gender || $UNDEF_VALUE;
    $feats->{'num'} = $node->gram_number || $UNDEF_VALUE;

    $feats->{'clause_num'} = $node->clause_number;

    my $sub_feats = inner() || {};
    return { %$feats, %$sub_feats };
};

override '_binary_features' => sub {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;

    my $feats = {};

    $feats->{gen_agree} = $self->_agree_feats($set_features->{'c^cand_gen'}, $set_features->{'a^anaph_gen'});
    $feats->{gen_join} = $self->_join_feats($set_features->{'c^cand_gen'}, $set_features->{'a^anaph_gen'});
    $feats->{num_agree} = $self->_agree_feats($set_features->{'c^cand_num'}, $set_features->{'a^anaph_num'});
    $feats->{num_join} = $self->_join_feats($set_features->{'c^cand_num'}, $set_features->{'a^anaph_num'});
    $feats->{gennum_agree} = $self->_join_feats($feats->{gen_agree}, $feats->{num_agree});

    $feats->{clause_dist} = $cand->clause_number - $anaph->clause_number;
    $feats->{sent_dist} = $cand->get_bundle->get_position - $anaph->get_bundle->get_position;
    $feats->{clausesent_dist} = $self->_join_feats($feats->{sent_dist}, $feats->{clause_dist});
    $feats->{gennum_clausesent} = $self->_join_feats($feats->{gennum_agree}, $feats->{clausesent_dist});

    
    return $feats;
};

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::Features::PersPron

=head1 DESCRIPTION

Features for coreference resolution of relative pronouns. Should be language-independent.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015-16 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
