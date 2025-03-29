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
        # L-participles and passive participles with the clitic auxiliary "-s" ("jsi").
        # Note that the person feature in the tag is unassigned although it could be "2".
        elsif($node->form() =~ m/^(.+)(s)$/i && $node->is_participle())
        {
            my $w1 = $1;
            my $w2 = $2;
            my $iset_hash = $node->iset()->get_hash();
            my $host_recipe = {'form' => $w1,
                'lemma'  => $node->lemma(), 'tag' => $node->tag(), 'conll_pos' => $node->conll_pos(),
                'iset'   => $iset_hash,
                'deprel' => $node->deprel()};
            my $aux_deprel = $node->iset()->is_passive() ? 'aux:pass' : 'aux';
            my $aux_recipe = {'form' => 'jsi',
                'lemma'  => 'být',          'tag' => 'AUX',        'conll_pos' => 'VB-S---2P-AA---',
                'iset'   => {'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'fin', 'mood' => 'ind', 'tense' => 'pres', 'voice' => 'act',
                             'person' => '2', 'number' => 'sing', 'polarity' => 'pos'},
                'deprel' => $aux_deprel};
            my @new_nodes = $self->split_fused_token($node, $host_recipe, $aux_recipe);
            $new_nodes[1]->set_parent($new_nodes[0]);
            # We must reset the deprel because if the original node was root, it has been set to root at both the new nodes.
            $new_nodes[1]->set_deprel($aux_deprel);
        }
        # Pronouns and conjunctions with the clitic auxiliary "-s" ("jsi").
        elsif($node->form() =~ m/^(co|jak|jestli|kdo|když|se|si|ty|vždyť|že)(s)$/i && $node->is_second_person())
        {
            my $w1 = $1;
            my $w2 = $2;
            my $iset_hash = $node->iset()->get_hash();
            delete($iset_hash->{person}) unless($node->form() =~ m/^tys$/i);
            delete($iset_hash->{number}) unless($node->form() =~ m/^(cos|kdos|tys)$/i);
            delete($iset_hash->{tense});
            delete($iset_hash->{voice});
            delete($iset_hash->{polarity});
            # Fix lemmas. One instance of "cos" has wrong lemma "cos", others have correct "co".
            if($node->lemma() eq 'cos')
            {
                $node->set_lemma('co');
            }
            # Normally we want to keep the sequence of the morphemes, i.e., "cos" will be split to "co jsi".
            # However, for "ses" and "sis", it sounds more natural to split them to "jsi se"/"jsi si" than to "se jsi/si jsi".
            # Therefore we will first prepare the node recipes and then use them in the desired order.
            my $host_recipe = {'form' => $w1,
                'lemma'  => $node->lemma(), 'tag' => $node->tag(), 'conll_pos' => $node->conll_pos(),
                'iset'   => $iset_hash,
                'deprel' => $node->deprel()};
            my $aux_recipe = {'form' => 'jsi',
                'lemma'  => 'být',          'tag' => 'AUX',        'conll_pos' => 'VB-S---2P-AA---',
                'iset'   => {'pos' => 'verb', 'verbtype' => 'aux', 'verbform' => 'fin', 'mood' => 'ind', 'tense' => 'pres', 'voice' => 'act',
                             'person' => '2', 'number' => 'sing', 'polarity' => 'pos'},
                'deprel' => 'aux'};
            my @new_nodes;
            my ($host, $aux);
            if($w1 =~ m/^s[ei]$/i)
            {
                @new_nodes = $self->split_fused_token($node, $aux_recipe, $host_recipe);
                $host = $new_nodes[1];
                $aux = $new_nodes[0];
            }
            else
            {
                @new_nodes = $self->split_fused_token($node, $host_recipe, $aux_recipe);
                $host = $new_nodes[0];
                $aux = $new_nodes[1];
            }
            # Typically, the parent of the fused token is an l-participle: "a ty ses jim vysmál do očí".
            # Then the auxiliary should be attached to the same parent, which has been done by default.
            # Sometimes the parent is an adjective and there is an l-participle copula: "aby sis byl vědom jeho ceny".
            # Sometimes it is more complicated: "mohla sis toho všimnout". Here, "sis" is attached to the
            # infinitive "všimnout" but the auxiliary "jsi" should be attached higher to "mohla".
            my $parent = $host->parent();
            if($parent->is_infinitive() && $parent->parent()->is_participle())
            {
                $aux->set_parent($parent->parent());
            }
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
                {'form' => $w2, 'lemma'  => 'neboť',        'tag' => 'CCONJ',      'conll_pos' => 'J^-------------',
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
        my $lemma = $node->lemma() // '';
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

Copyright © 2014, 2015 by Institute of Formal and Applied Linguistics, Charles University, Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
