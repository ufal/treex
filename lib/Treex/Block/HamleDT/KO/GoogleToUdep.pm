package Treex::Block::HamleDT::KO::GoogleToUdep;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::StanfordToUD;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'mul::google',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);



#------------------------------------------------------------------------------
# Stačilo by nám process_atree(), ale nadřazená třída zatím z historických
# důvodů používá process_zone(), takže kdybychom tady použili process_atree(),
# vůbec by se nezavolalo.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $zone->get_atree();
    $self->convert_tags($root);
    $self->convert_deprels($root);
    $self->fix_annotation_errors($root);
    my $builder = new Treex::Tool::PhraseBuilder::StanfordToUD
    (
        'prep_is_head'           => 0,
        'coordination_head_rule' => 'first_conjunct'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    $self->fix_root_punctuation($root);
    $self->fix_sentence_segmentation($root);
    $self->fix_false_root_labels($root);
    # Occasionally a final full stop sticks together with the preceding word.
    $self->fix_tokenization($root);
}



#------------------------------------------------------------------------------
# Converts tags of all nodes to Interset and UPOS.
#------------------------------------------------------------------------------
sub convert_tags
{
    my $self   = shift;
    my $root   = shift;
    foreach my $node ( $root->get_descendants() )
    {
        # We will want to save the original tag (or a part thereof) in conll/pos.
        ###!!! However! We are now using conll/cpos as input for Interset, while conll/pos already contains what we want to preserve!
        #my $origtag = $self->get_input_tag_for_interset($node);
        my $origtag = $node->conll_pos();
        # Now that we have a copy of the original tag, we can convert it.
        $self->decode_iset( $node );
        $self->set_upos_tag( $node );
        ###!!! There are currently no features, except that Interset always sets NumType=Card for numbers.
        ###!!! It does not make sense to have just this feature, especially when we cannot be sure that it's always correct.
        #$node->iset()->clear('numtype');
        # For the case we later access the CoNLL attributes, reset them as well.
        # (We can still specify other source attributes in Write::CoNLLX and similar blocks.)
        my $tag = $node->tag(); # now the universal POS tag
        $node->set_conll_cpos($tag);
        $node->set_conll_pos($origtag);
        $node->set_conll_feat($node->iset()->as_string_conllx());
    }
}



#------------------------------------------------------------------------------
# Different source treebanks may use different attributes to store information
# needed by Interset drivers to decode the Interset feature values. By default,
# the CoNLL 2006 fields CPOS, POS and FEAT are concatenated and used as the
# input tag. If the morphosyntactic information is stored elsewhere (e.g. in
# the tag attribute), the Harmonize block of the respective treebank should
# redefine this method. Note that even CoNLL 2009 differs from CoNLL 2006.
#------------------------------------------------------------------------------
sub get_input_tag_for_interset
{
    my $self   = shift;
    my $node   = shift;
    # If we read the source CoNLL-X file using Read::CoNLLX with default parameters,
    # tag contains the fine-grained tag from the POS column. For example, the verb
    # "곳입니다" has the tag NOMCOP. These tags are potentially useful but at present
    # we do not have the corresponding Interset driver. Therefore we will use only
    # the coarse-grained Google Universal POS tag.
    #return $node->tag();
    return $node->conll_cpos();
}



###!!! This block started as a clone of PT::GoogleToUdep, hence the examples below are Portuguese.
###!!! We will adapt it as needed.
my %conversion_table =
(
    'ROOT'      => 'root',
    'acomp'     => 'xcomp:adj', # "passageiro se sente prejudicado" acomp(sente, prejudicado) (doplněk)
    'adp'       => 'case', # leaf adposition; needs special treatment (see below) to distinguish between 'case' and 'mark'
    'adpcomp'   => 'scarg', # clausal argument of adposition (e.g. "para acreditar"); structural transformation needed
    'adpmod'    => 'nmod', # adpositional phrase acting as a non-core dependent
    'adpobj'    => 'adparg', # nominal argument of adposition; structural transformation needed
    'advcl'     => 'advcl',
    'advmod'    => 'advmod',
    'amod'      => 'amod',
    'appos'     => 'appos',
    'attr'      => 'pnom', # predicative attribute (nominal predicate); structural transformation needed
    'aux'       => 'aux',
    'auxpass'   => 'aux:pass',
    'cc'        => 'cc',
    'ccomp'     => 'ccomp',
    'compmod'   => 'flat', # Typically first name attached to last name (reversion needed). Can it be a compound noun too?
    'conj'      => 'conj',
    'csubj'     => 'csubj',
    'csubjpass' => 'csubj:pass',
    'dep'       => 'dep',
    'det'       => 'det',
    'dobj'      => 'obj',
    'infmod'    => 'acl:inf', # infinitival clause used as a non-core dependent; rare; e.g. modifying a noun in "um pedido..., a ser analisado pelo STF, ..."
    'iobj'      => 'iobj',
    'mark'      => 'mark',
    'mwe'       => 'fixed',
    'neg'       => 'advmod',
    'nmod'      => 'nmod',
    'nsubj'     => 'nsubj',
    'nsubjpass' => 'nsubj:pass',
    'num'       => 'nummod',
    'p'         => 'punct',
    'parataxis' => 'parataxis',
    'partmod'   => 'acl:part', # participle acting as an adjectival modifier
    'poss'      => 'det:poss', # possessive determiner (pronoun)
    'prt'       => 'expl', # the reflexive pronoun "se" when tagged as particle and used with an inherently reflexive verb ###!!! also compound:prt in Germanic languages?
    'rcmod'     => 'acl:relcl', # relative clause
    'xcomp'     => 'xcomp'
);



#------------------------------------------------------------------------------
# Convert dependency relation labels. The version 2 Universal Dependency
# Treebanks use a version of the Stanford dependencies, thus they are quite
# close but not identical to Universal Dependencies.
#------------------------------------------------------------------------------
sub convert_deprels
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        ###!!! We need a well-defined way of specifying where to take the source label.
        ###!!! Currently we try three possible sources with defined priority (if one
        ###!!! value is defined, the other will not be checked).
        my $deprel = $node->deprel();
        $deprel = $node->afun() if(!defined($deprel));
        $deprel = $node->conll_deprel() if(!defined($deprel));
        $deprel = 'NR' if(!defined($deprel));
        my $parent = $node->parent();
        # 'adp' is a leaf adposition. It may have two causes:
        # 1. The adpositional phrase is a core dependent such as 'iobj'. Unlike adpositional modifiers, objects are headed by nominals.
        #    Example: "acarretou danos/dobj ao conjunto/iobj"
        # 2. Auxiliary verb + preposition + infinitive (such as Portuguese passar a acreditar); both the auxiliary and the preposition are attached to the main verb.
        # We want 'case' in 1. and 'mark' in 2.
        if($deprel eq 'adp')
        {
            if($parent->is_verb())
            {
                $deprel = 'mark';
            }
            else
            {
                $deprel = 'case';
            }
        }
        elsif(exists($conversion_table{$deprel}))
        {
            $deprel = $conversion_table{$deprel};
        }
        $node->set_deprel($deprel);
    }
}



#------------------------------------------------------------------------------
# Fixes a few known annotation errors that appear in the data.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
    }
}



#------------------------------------------------------------------------------
# There are sentences where multiple nodes are attached to the root. A few of
# them are just because of the final punctuation being attached to the root
# instead of the main predicate. This method will re-attach such punctuation.
#------------------------------------------------------------------------------
sub fix_root_punctuation
{
    my $self = shift;
    my $root = shift;
    my @topnodes = $root->get_children({'ordered' => 1});
    if(scalar(@topnodes)>1)
    {
        my $last_tn;
        foreach my $tn (@topnodes)
        {
            if($tn->is_punctuation())
            {
                if(defined($last_tn))
                {
                    $tn->set_parent($last_tn);
                    $tn->set_deprel('punct');
                }
                else
                {
                    $tn->set_deprel('root');
                }
            }
            else
            {
                $last_tn = $tn;
                $tn->set_deprel('root');
            }
        }
    }
}



#------------------------------------------------------------------------------
# There are sentences where multiple nodes are attached to the root. If we have
# sorted out punctuation (see fix_root_punctuation() above), the remaining
# cases are multiple sentences that ended up in one tree because the sentence
# segmenter failed to separate them. This method will take the subtree of each
# top node and make it an independent tree. Note that it will not always solve
# the entire problem. Sometimes a token on the border of the two subtrees
# should be split, too (either last word + punctuation, or last word + punctu-
# ation + first word of the next sentence are merged in one token).
#------------------------------------------------------------------------------
sub fix_sentence_segmentation
{
    my $self = shift;
    my $root = shift;
    my @topnodes = $root->get_children({'ordered' => 1});
    if(scalar(@topnodes)>1)
    {
        # Sort out the nodes of the individual sentences.
        my @sentences;
        foreach my $tn (@topnodes)
        {
            my @sentence = $tn->get_descendants({'add_self' => 1, 'ordered' => 1});
            push(@sentences, \@sentence);
        }
        # Create bundles for the new sentences.
        my $current_bundle = $root->get_bundle();
        my $document = $current_bundle->get_document();
        for(my $i = 1; $i<=$#sentences; $i++)
        {
            # Note that the new bundle will contain only one zone.
            # If there are other zones in the source bundle (probably the 'orig' zone?), they will not be copied.
            # The entire original tree will stay with the converted tree of the first sentence.
            my $new_bundle = $document->create_bundle({'after' => $current_bundle});
            my $new_zone = $new_bundle->create_zone($self->language(), $self->selector());
            my $new_tree = $new_zone->create_atree();
            # Get the minimal and maximal ords in this sentence.
            my $minord;
            my $maxord;
            foreach my $node (@{$sentences[$i]})
            {
                if(!defined($minord) || $node->ord() < $minord)
                {
                    $minord = $node->ord();
                }
                if(!defined($maxord) || $node->ord() > $maxord)
                {
                    $maxord = $node->ord();
                }
            }
            # Reattach the top node of the sentence to the root of the new tree.
            foreach my $node (@{$sentences[$i]})
            {
                my $pord = $node->parent()->ord();
                if($pord < $minord || $pord > $maxord)
                {
                    $node->set_parent($new_tree);
                }
            }
            # Modify the ords in the new sentence so that they start at 1 again.
            $new_tree->_normalize_node_ordering();
            # Make the new bundle current, just in case we will be creating another bundle, so that we know where to place it.
            $current_bundle = $new_bundle;
        }
        $root->_normalize_node_ordering();
    }
}



#------------------------------------------------------------------------------
# Makes sure that the root relation is not used anywhere alse than for the top
# node. We are checking it separately at the end because we could have
# introduced the error when manipulating multiple top nodes.
#------------------------------------------------------------------------------
sub fix_false_root_labels
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'root' && !$node->parent()->is_root())
        {
            $node->set_deprel('dep');
        }
    }
}



#------------------------------------------------------------------------------
# Punctuation is kept as one token with the neighboring word in the input data.
# This method cuts it off.
#------------------------------------------------------------------------------
sub fix_tokenization
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    my $hit = 0;
    for(my $i = 0; $i <= $#nodes; $i++)
    {
        my $form = $nodes[$i]->form();
        # Some word forms contain spaces, which is not allowed.
        # Some contain the \x{FEFF} character, which is also a bug.
        if($form =~ s/[\s\x{FEFF}\x{FFFE}]//g)
        {
            $form = '_' if($form eq '');
            $nodes[$i]->set_form($form);
        }
        # Look for non-punctuation followed by punctuation, e.g. "주었다."
        if($form =~ m/^(\PP+)(\pP+)$/)
        {
            my $nonpunct = $1;
            my $punct = $2;
            $nodes[$i]->set_form($nonpunct);
            my $pnode = $nodes[$i]->create_child();
            $pnode->set_no_space_after($nodes[$i]->no_space_after());
            $nodes[$i]->set_no_space_after(1);
            $pnode->set_form($punct);
            $pnode->set_lemma($punct);
            $pnode->set_tag('PUNCT');
            $pnode->iset()->set('pos', 'punc');
            # XPOSTAG of punctuation is the punctuation symbol itself.
            $pnode->set_conll_pos($punct);
            $pnode->set_deprel('punct');
            $pnode->wild()->{ord} = $nodes[$i]->ord()+0.1;
            $hit = 1;
        }
    }
    # Fix ords in the entire sentence.
    if($hit)
    {
        @nodes = $root->get_descendants();
        foreach my $node (@nodes)
        {
            if(!defined($node->wild()->{ord}))
            {
                $node->wild()->{ord} = $node->ord();
            }
        }
        @nodes = sort {$a->wild()->{ord} <=> $b->wild()->{ord}} (@nodes);
        for(my $i = 0; $i <= $#nodes; $i++)
        {
            $nodes[$i]->_set_ord($i+1);
            delete($nodes[$i]->wild()->{ord});
        }
    }
    my $text = $self->collect_sentence_text(@nodes);
    $root->get_zone()->set_sentence($text);
}



#------------------------------------------------------------------------------
# Returns the sentence text, observing the current setting of no_space_after
# and of the fused multi-word tokens (still stored as wild attributes).
#------------------------------------------------------------------------------
sub collect_sentence_text
{
    my $self = shift;
    my @nodes = @_;
    my $text = '';
    for(my $i = 0; $i<=$#nodes; $i++)
    {
        my $node = $nodes[$i];
        my $wild = $node->wild();
        my $fused = $wild->{fused};
        if(defined($fused) && $fused eq 'start')
        {
            my $first_fused_node_ord = $node->ord();
            my $last_fused_node_ord = $wild->{fused_end};
            my $last_fused_node_no_space_after = 0;
            # We used to save the ord of the last element with every fused element but now it is no longer guaranteed.
            # Let's find out.
            if(!defined($last_fused_node_ord))
            {
                for(my $j = $i+1; $j<=$#nodes; $j++)
                {
                    $last_fused_node_ord = $nodes[$j]->ord();
                    $last_fused_node_no_space_after = $nodes[$j]->no_space_after();
                    last if(defined($nodes[$j]->wild()->{fused}) && $nodes[$j]->wild()->{fused} eq 'end');
                }
            }
            else
            {
                my $last_fused_node = $nodes[$last_fused_node_ord-1];
                log_fatal('Node ord mismatch') if($last_fused_node->ord() != $last_fused_node_ord);
                $last_fused_node_no_space_after = $last_fused_node->no_space_after();
            }
            if(defined($first_fused_node_ord) && defined($last_fused_node_ord))
            {
                $i += $last_fused_node_ord - $first_fused_node_ord;
            }
            else
            {
                log_warn("Cannot determine the span of a fused token");
            }
            $text .= $wild->{fused_form};
            $text .= ' ' unless($last_fused_node_no_space_after);
        }
        else
        {
            $text .= $node->form();
            $text .= ' ' unless($node->no_space_after());
        }
    }
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return $text;
}



1;

=over

=item Treex::Block::HamleDT::KO::GoogleToUdep

Converts Korean trees from the Google Universal Dependency Treebanks
version 2 (2014, Universal Stanford Dependencies) to Universal Dependencies.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016, 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.