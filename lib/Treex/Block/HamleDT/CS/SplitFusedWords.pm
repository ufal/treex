package Treex::Block::HamleDT::CS::SplitFusedWords;
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
    $self->split_multiword_entities_cltt($root);
    $self->fix_jako_kdyby($root);
}



#------------------------------------------------------------------------------
# Splits fused subordinating conjunction + conditional auxiliary to two nodes:
# abych, abys, aby, abychom, abyste
# kdybych, kdybys, kdyby, kdybychom, kdybyste
# Note: In theory there are other fused words that should be split (udělals,
# tos, sis, ses, cos, tys, žes, proň, oň, naň) but they do not appear in the
# PDT 3.0 data.
#------------------------------------------------------------------------------
sub split_fused_words
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        if($node->form() =~ m/^(a|kdy)(bych|bys|by|bychom|byste)$/i)
        {
            my $w1 = $1;
            my $w2 = $2;
            $w1 =~ s/^(a)$/$1by/i;
            $w1 =~ s/^(kdy)$/$1ž/i;
            my ($pchar, $person, $nchar, $number);
            if($w2 =~ m/^(bych|bychom)$/i)
            {
                $pchar = '1';
                $person = '1';
            }
            elsif($w2 =~ m/^(bys|byste)$/i)
            {
                $pchar = '2';
                $person = '2';
            }
            else
            {
                $pchar = '-';
                $person = '3';
            }
            if($w2 =~ m/^(bych|bys)$/i)
            {
                $nchar = 'S';
                $number = 'sing';
            }
            elsif($w2 =~ m/^(bychom|byste)$/i)
            {
                $nchar = 'P';
                $number = 'plur';
            }
            else
            {
                $nchar = '-';
                $number = '';
            }
            my @new_nodes = $self->split_fused_token
            (
                $node,
                {'form' => $w1, 'lemma'  => lc($w1), 'tag' => 'SCONJ', 'conll_pos' => 'J,-------------',
                                'iset'   => {'pos' => 'conj', 'conjtype' => 'sub'},
                                'deprel' => 'mark'},
                {'form' => $w2, 'lemma'  => 'být',   'tag' => 'AUX',   'conll_pos' => 'Vc-'.$nchar.'---'.$pchar.'-------',
                                'iset'   => {'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'fin', 'mood' => 'cnd', 'number' => $number, 'person' => $person},
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
            # Example: "A kdyby..."
            # In such cases we now have two roots, "když" and "by". We should promote the conditional auxiliary and attach the conjunction as its child.
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
        elsif($node->form() =~ m/^(na|o|za)(č)$/i && $node->iset()->adpostype() eq 'preppron')
        {
            my $w1 = $1;
            my $w2 = $2;
            my $iset_hash = $node->iset()->get_hash();
            my @new_nodes = $self->split_fused_token
            (
                $node,
                {'form' => $w1,  'lemma'  => lc($w1), 'tag' => 'ADP',  'conll_pos' => 'RR--4----------',
                                 'iset'   => {'pos' => 'adp', 'adpostype' => 'prep', 'case' => 'acc'},
                                 'deprel' => 'case'},
                {'form' => 'co', 'lemma'  => 'co',    'tag' => 'PRON', 'conll_pos' => 'PQ--4----------',
                                 'iset'   => {'pos' => 'noun', 'prontype' => 'int|rel', 'gender' => 'neut', 'number' => 'sing', 'case' => 'acc'},
                                 'deprel' => $node->deprel()}
            );
            $new_nodes[0]->set_parent($new_nodes[1]);
        }
        elsif($node->form() =~ m/^(.+)(ť)$/i && $node->iset()->verbtype() eq 'verbconj')
        {
            my $w1 = $1;
            my $w2 = $2;
            my $iset_hash = $node->iset()->get_hash();
            delete($iset_hash->{verbtype});
            my @new_nodes = $self->split_fused_token
            (
                $node,
                {'form' => $w1, 'lemma'  => $node->lemma(), 'tag' => $node->tag(), 'conll_pos' => 'Vt-S---3P-NA--2',
                                'iset'   => $iset_hash,
                                'deprel' => $node->deprel()},
                {'form' => $w2, 'lemma'  => 'neboť',        'tag' => 'CONJ',       'conll_pos' => 'J^-------------',
                                'iset'   => {'pos' => 'conj', 'conjtype' => 'coor'},
                                'deprel' => 'cc'}
            );
            $new_nodes[1]->set_parent($new_nodes[0]);
            $new_nodes[1]->set_deprel('cc');
        }
    }
}



#------------------------------------------------------------------------------
# Splits multi-word entities that are treated as single tokens in the Czech
# Legal Text Treebank (CLTT).
#------------------------------------------------------------------------------
sub split_multiword_entities_cltt
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        ###!!! Provizorní řešení slov a lemmat, která obsahují mezery. Správně bychom je ale měli rozsekat na uzly!
        my $form = $node->form();
        if($form =~ s/ /_/g)
        {
            $node->set_form($form);
        }
        my $lemma = $node->lemma();
        if($lemma =~ s/ /_/g)
        {
            $node->set_lemma($lemma);
        }
        # Some entities are enclosed in quotation marks, which are part of the token. Example:
        # "* Finanční výsledek hospodaření"
        # Remove the quotation marks first.
        if($node->form() =~ m/^"(.+)"$/)
        {
            my $w = $1;
            my $iset_hash = $node->iset()->get_hash();
            ###!!! Ovšem s uvozovkami bychom neměli zacházet jako s multi-word tokenem. Měli bychom je prostě obyčejně tokenizovat!
            my @new_nodes = $self->split_fused_token
            (
                $node,
                {'form' => '"', 'lemma'  => '"', 'tag' => 'PUNCT', 'conll_pos' => 'Z:-------------',
                                'iset'   => {'pos' => 'punc'},
                                'deprel' => 'punct'},
                {'form' => $w,  'lemma'  => $node->lemma(), 'tag' => $node->tag(), 'conll_pos' => $node->conll_pos(),
                                'iset'   => $iset_hash,
                                'deprel' => $node->deprel()},
                {'form' => '"', 'lemma'  => '"', 'tag' => 'PUNCT', 'conll_pos' => 'Z:-------------',
                                'iset'   => {'pos' => 'punc'},
                                'deprel' => 'punct'}
            );
            $new_nodes[0]->set_parent($new_nodes[1]);
            $new_nodes[2]->set_parent($new_nodes[1]);
        }
    }
    ###!!! Tohle teď musíme udělat, když nahoře nahrazujeme mezery podtržítky.
    $root->get_zone()->set_sentence($root->collect_sentence_text());
}



#------------------------------------------------------------------------------
# Czech "jako kdyby" ("as if") can be considered a multi-word expression.
# In UD, "kdyby" is treated as a fusion of "když+by", hence we have "jako když
# by". Both "když" and "by" are attached to "jako" but this is an example where
# we actually want to attach each part to a different parent: "když" to "jako"
# (fixed), and "by" (aux) to the verb parent of "jako".
#------------------------------------------------------------------------------
sub fix_jako_kdyby
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    for(my $i = 0; $i+2 <= $#nodes; $i++)
    {
        my $n0 = $nodes[$i];
        my $n1 = $nodes[$i+1];
        my $n2 = $nodes[$i+2];
        if(defined($n0->form()) && lc($n0->form()) eq 'jako' &&
           defined($n1->form()) && lc($n1->form()) eq 'když' &&
           defined($n2->form()) && $n2->form() =~ m/^by(ch|s|chom|ste)?$/i &&
           $n1->parent() == $n0 && $n2->parent() == $n0)
        {
            my $verb = $n0->parent();
            if(!$verb->is_root() && $verb->is_verb())
            {
                $n2->set_parent($verb);
                $n2->set_deprel('aux');
            }
            $n1->set_deprel('fixed');
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::CS::SplitFusedWords

Splits certain tokens to syntactic words according to the guidelines of the
Universal Dependencies.

This block should be called after the tree has been converted to Universal
Dependencies so that the tags and dependency relation labels are from the UD
set.

=back

=cut

# Copyright 2014, 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
