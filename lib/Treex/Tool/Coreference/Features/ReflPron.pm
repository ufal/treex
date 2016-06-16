package Treex::Tool::Coreference::Features::ReflPron;

use Moose;
use Treex::Core::Common;
use List::MoreUtils qw/any/;
use Treex::Tool::Coreference::NodeFilter;

extends 'Treex::Tool::Coreference::BaseCorefFeatures';

my $UNDEF_VALUE = "undef";

augment '_unary_features' => sub {
    my ($self, $node, $type) = @_;

    my $feats = {};

    $feats->{'id'} = $node->get_address;

    my $anode = $node->get_lex_anode;
    $feats->{'lemma'} = defined $anode ? $anode->lemma : $UNDEF_VALUE;

    if ($type eq 'cand') {
        $feats->{'is_refl'} = Treex::Tool::Coreference::NodeFilter::matches($node, ['reflpron']) ? 1 : 0;
    }

    #$feats->{'tlemma'} = $node->t_lemma;
    #$feats->{'fmm'} = $node->formeme;

    my $sub_feats = inner() || {};
    return { %$feats, %$sub_feats };
};

override '_binary_features' => sub {
    my ($self, $set_features, $anaph, $cand, $candord) = @_;

    my $feats = {};

    $feats->{clause_subject} = $self->_is_clause_subject($anaph, $cand) ? 1 : 0;
    $feats->{is_subject} = $self->_is_subject($cand) ? 1 : 0;

    $feats->{in_clause} = $anaph->clause_number eq $cand->clause_number ? 1 : 0;
    $feats->{refl_in_clause} = $set_features->{'c^cand_is_refl'} . "_" . $feats->{in_clause};
    
    return $feats;
};

# this is a simplified version of what is in Block::A2T::MarkReflpronCoref
sub _is_clause_subject {
    my ($self, $anaph, $cand) = @_;
    my $clause = $anaph->get_clause_head;
    return 0 if ($clause->is_root);
    my ($clause_subj) = grep {$self->_is_subject($_)} $clause->get_echildren( { or_topological => 1 } );
    return (defined $clause_subj) && ($clause_subj == $cand);
}

sub _is_subject {
    my ($self, $t_node) = @_;
    return ($t_node->formeme // '') =~ /^(n:1|n:subj|drop)$/;
}

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Coreference::Features::ReflPron

=head1 DESCRIPTION

A language-independent feature extractor for CR of reflexive pronouns.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015-16 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
