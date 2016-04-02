package Treex::Tool::Coreference::CS::RelPronFeatures;

use Moose;
use Treex::Core::Common;
use List::MoreUtils qw/any/;

extends 'Treex::Tool::Coreference::CorefFeatures';

augment '_unary_features' => sub {
    my ($self, $node, $type) = @_;

    my $feats = {};

    $feats->{'tlemma'} = $node->t_lemma;
    $feats->{'fmm'} = $node->formeme;

    $feats->{'gen'} = $node->gram_gender // "";
    $feats->{'num'} = $node->gram_number // "";

    my $sub_feats = inner() || {};
    return { %$feats, %$sub_feats };
};

override '_binary_features' => sub {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;

    my $feats = {};

    $feats->{clause_parent} = $self->_is_clause_parent($anaph, $cand) ? 1 : 0;
    
    $feats->{gen_agree} = $self->_agree_feats($set_features->{cand_gen}, $set_features->{anaph_gen});
    $feats->{gen_join} = $self->_join_feats($set_features->{cand_gen}, $set_features->{anaph_gen});
    $feats->{num_agree} = $self->_agree_feats($set_features->{cand_num}, $set_features->{anaph_num});
    $feats->{num_join} = $self->_join_feats($set_features->{cand_num}, $set_features->{anaph_num});

    return $feats;
};

# this is a simplified version of what is in Block::A2T::CS::MarkRelClauseCoref
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

Treex::Tool::Coreference::CS::RelPronFeatures

=head1 DESCRIPTION

An abstract class for features needed in personal pronoun coreference
resolution. The features extracted here should be language independent.

=head1 METHODS

=head2 To be implemented

These methods must be implemented in classes that consume this role.

=over

#=item _build_feature_names 
#
#A list of features required for training/resolution. Without implementing 
#in a subclass it throws an exception.

=back

=head2 Already implemented

=over

=item _unary_features

It returns a hash of unary features that relate either to the anaphor or the
antecedent candidate. 

Contains just language-independent features. It should be extended by 
overriding in a subclass.

=item _binary_features 

It returns a hash of binary features that combine both the anaphor and the
antecedent candidate.

Contains just language-independent features. It should be extended by 
overriding in a subclass.

=back

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
