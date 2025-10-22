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
        # Treat "aby" ("so that") similarly to Czech, although Slovak does not
        # have the aorist-like inflected forms of the conditional auxiliary.
        # Nevertheless, there is the Mood=Cnd feature, which should ideally
        # occur on the auxiliary "by", not on a subjunction. Example:
        # "Známe uskromňovacie heslo "Jeme preto, aby sme žili." nie je pravdivé." (train/inzine:inzine7190-01:.s.)
        # Original annotation OY (SCONJ, Mood=Cnd). Ordinary subjunctions have just O (SCONJ). The auxiliary "by" has Y (AUX, Mood=Cnd).
        if($node->form() =~ m/^(a|ke|ako|nieže)(by)$/i)
        {
            my $w1 = $1;
            my $w2 = $2;
            $w1 =~ s/^(a)$/$1by/i;
            $w1 =~ s/^(ke)$/$1ď/i;
            my @new_nodes = $self->split_fused_token
            (
                $node,
                {'form' => $w1, 'lemma'  => lc($w1), 'tag' => 'SCONJ', 'conll_pos' => 'O',
                                'iset'   => {'pos' => 'conj', 'conjtype' => 'sub'},
                                'deprel' => 'mark'},
                {'form' => $w2, 'lemma'  => 'by',    'tag' => 'AUX',   'conll_pos' => 'Y',
                                'iset'   => {'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'fin', 'mood' => 'cnd'},
                                'deprel' => 'aux'}
            );
            foreach my $child ($new_nodes[0]->children())
            {
                # The second node is conditional auxiliary and it should depend on the participle of the content verb.
                if(($parent->is_root() || !$parent->is_participle()) && $child->is_participle())
                {
                    $new_nodes[1]->set_parent($child);
                    $new_nodes[1]->set_deprel('aux');
                    last;
                }
            }
            # In case of ellipsis, there is no participle and the multi-word token is attached to the root.
            # Example: "A keby..."
            # In such cases we now have two roots, "keď" and "by". We should promote the conditional auxiliary and attach the conjunction as its child.
            if($new_nodes[0]->parent()->is_root() && $new_nodes[1]->parent()->is_root())
            {
                $new_nodes[0]->set_parent($new_nodes[1]);
                $new_nodes[0]->set_deprel('mark');
                foreach my $child ($new_nodes[0]->children())
                {
                    $child->set_parent($new_nodes[1]);
                }
            }
        }
        elsif($node->form() =~ m/^(do|na|o|po|pre|u|za)(ň(?:ho)?)$/i && $node->iset()->adpostype() eq 'preppron')
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
