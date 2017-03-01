package Treex::Tool::Coreference::Features::RelPron;

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

    my $sub_feats = inner() || {};
    return { %$feats, %$sub_feats };
};

override '_binary_features' => sub {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;

    my $feats = {};

    $feats->{clause_parent} = $self->_is_clause_parent($anaph, $cand) ? 1 : 0;
    
    $feats->{gen_agree} = $self->_agree_feats($set_features->{'c^cand_gen'}, $set_features->{'a^anaph_gen'});
    $feats->{gen_join} = $self->_join_feats($set_features->{'c^cand_gen'}, $set_features->{'a^anaph_gen'});
    $feats->{num_agree} = $self->_agree_feats($set_features->{'c^cand_num'}, $set_features->{'a^anaph_num'});
    $feats->{num_join} = $self->_join_feats($set_features->{'c^cand_num'}, $set_features->{'a^anaph_num'});
    
    $feats->{cand_ancestor} = (any {$_ == $anaph} $cand->get_descendants()) ? 1 : 0;
    $feats->{cand_ancestor_num_agree} = $feats->{cand_ancestor} . "_" . $feats->{num_agree};
    $feats->{cand_ancestor_gen_agree} = $feats->{cand_ancestor} . "_" . $feats->{gen_agree};
    $feats->{cand_ancestor_gennum_agree} = $feats->{cand_ancestor} . "_" . $feats->{gen_agree} . "_" . $feats->{num_agree};

    my $aanaph = $anaph->get_lex_anode;
    my $acand = $cand->get_lex_anode;
    if (defined $aanaph && defined $acand) {
        my @anodes = $aanaph->get_root->get_descendants({ordered => 1});
        my @nodes_between = @anodes[$acand->ord .. $aanaph->ord-2];
        
        $feats->{is_comma_between} = any {$_->form eq ","} @nodes_between;
        $feats->{words_between_count} = scalar @nodes_between;
    }


    return $feats;
};

# this is a simplified version of what is in Block::A2T::MarkRelClauseCoref
sub _is_clause_parent {
    my ($self, $anaph, $cand) = @_;
    my $clause = $anaph->get_clause_head;
    return 0 if ($clause->is_root);
    my @parents = $clause->get_eparents( { or_topological => 1 } );
    return any {$_ == $cand} @parents;
}


1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::Features::RelPron

=head1 DESCRIPTION

Features for coreference resolution of relative pronouns. Should be language-independent.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015-16 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
