package Treex::Block::HamleDT::SK::SplitFusedWords;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::SplitFusedWords';



#------------------------------------------------------------------------------
# Splits certain tokens to syntactic words according to the guidelines of the
# Universal Dependencies. This block should be called after the tree has been
# converted to UD, not before!
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $zone->get_atree();
    $self->split_fused_words($root);
}



#------------------------------------------------------------------------------
# Splits fused preposition + personal pronoun in Slovak.
#------------------------------------------------------------------------------
sub split_fused_words
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        if($node->form() =~ m/^(do|na|o|po|pre|u|za)(ň(?:ho)?)$/i && $node->iset()->adpostype() eq 'preppron')
        {
            my $w1 = $1;
            my $w2 = $2;
            my $gender = $node->is_neuter() ? 'n' : $node->is_inanimate() ? 'i' : 'm';
            my $case = $node->is_genitive() ? '2' : '4';
            my $l2 = $node->is_neuter() ? 'ono' : 'on';
            my $iset_hash = $node->iset()->get_hash();
            delete($iset_hash->{adpostype});
            my @new_nodes = $self->split_fused_token
            (
                $node,
                {'form' => $w1,    'lemma'  => lc($w1), 'tag' => 'ADP',  'conll_pos' => 'Eu'.$case,
                                   'iset'   => {'pos' => 'adp', 'adpostype' => 'prep', 'case' => $node->iset()->case()},
                                   'deprel' => 'case'},
                {'form' => 'neho', 'lemma'  => $l2,     'tag' => 'PRON', 'conll_pos' => 'PF'.$gender.'s'.$case,
                                   'iset'   => $iset_hash,
                                   'deprel' => $node->deprel()}
            );
            $new_nodes[0]->set_parent($new_nodes[1]);
        }
    }
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::SK::SplitFusedWords

=head1 DESCRIPTION

Splits certain tokens to syntactic words according to the guidelines of the
Universal Dependencies.

This block should be called after the tree has been converted to Universal
Dependencies so that the tags and dependency relation labels are from the UD
set.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014, 2015, 2021 by Institute of Formal and Applied Linguistics, Charles University, Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
