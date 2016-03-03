package Treex::Block::HamleDT::Harmonize;
use Moose;
use Treex::Core::Common;
use Treex::Core::Coordination;
use Treex::Core::Cloud;
use Lingua::Interset qw(decode encode);
use utf8;
extends 'Treex::Core::Block';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'The default value must be set in blocks derived from this block. '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);



#------------------------------------------------------------------------------
# Reads the a-tree, converts the original morphosyntactic tags to the PDT
# tagset, converts dependency relation tags to afuns and transforms the tree to
# adhere to the PDT guidelines. This method must be overriden in the subclasses
# that know about the differences between the style of their treebank and that
# of PDT. However, here is a sample of what to do. (Actually it's not just a
# sample. You can call it from the overriding method as
# $a_root = $self->SUPER::process_zone($zone);. Call this first and then do
# your specific stuff.)
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $root = $zone->get_atree();

    # Adjust the sentence id that will be eventually printed in the CoNLL-U file.
    # Now we probably have something like "a_tree-ca-s30-root". Both "a_tree-" and "-root" are superfluous.
    my $id = $root->id();
    $id =~ s/^a_tree-//;
    $id =~ s/-root$//;
    $root->set_id($id);

    # Convert CoNLL POS tags and features to Interset and PDT if possible.
    $self->convert_tags( $root );

    # Conversion from dependency relation tags to afuns (analytical function tags) must be done always
    # and it is almost always treebank-specific (only a few treebanks use the same tagset as the PDT).
    $root->set_afun('AuxS');
    $self->convert_deprels($root);
    $self->fix_annotation_errors($root);

    # The return value can be used by the overriding methods of subclasses.
    return $root;
}



#------------------------------------------------------------------------------
# Converts tags of all nodes to Interset and PDT tagset.
#------------------------------------------------------------------------------
sub convert_tags
{
    my $self   = shift;
    my $root   = shift;
    foreach my $node ( $root->get_descendants() )
    {
        # We will want to save the original tag (or a part thereof) in conll/pos.
        my $origtag = $self->get_input_tag_for_interset($node);
        # 3 fields probably means CPOS-POS-FEAT
        # 2 fields probably means CPOS-POS
        my @fields = split(/\t/, $origtag);
        if(scalar(@fields)>=2)
        {
            $origtag = $fields[1];
            if(defined($fields[2]) && $fields[2] ne '_' && length($fields[2])<30)
            {
                $origtag .= '|'.$fields[2];
            }
        }
        # Now that we have a copy of the original tag, we can convert it.
        $self->decode_iset( $node );
        $self->set_pdt_tag( $node );
        # For the case we later access the CoNLL attributes, reset them as well.
        # (We can still specify other source attributes in Write::CoNLLX and similar blocks.)
        my $tag = $node->tag(); # now the PDT tag
        $node->set_conll_cpos(substr($tag, 0, 1));
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
    my $conll_cpos = $node->conll_cpos();
    my $conll_pos  = $node->conll_pos();
    my $conll_feat = $node->conll_feat();
    return "$conll_cpos\t$conll_pos\t$conll_feat";
}



#------------------------------------------------------------------------------
# Decodes the part-of-speech tag and features from a CoNLL treebank into
# Interset features. Stores the features with the node.
#------------------------------------------------------------------------------
sub decode_iset
{
    my $self   = shift;
    my $node   = shift;
    my $driver = $self->iset_driver();
    my $src_tag = $self->get_input_tag_for_interset($node);
    my $f = decode($driver, $src_tag);
    log_fatal("Could not decode '$src_tag' with '$driver' Interset driver") if(!defined($f));
    $node->set_iset($f);
}
sub convert_tag
{
    my $self = shift;
    log_warn('The HamleDT::Harmonize::convert_tag() method is deprecated as of 2016-02-18. Use decode_iset() instead.');
    return $self->decode_iset(@_);
}



#------------------------------------------------------------------------------
# Interset is the main means of storing part of speech and morphosyntactic
# features of a node. The tag attribute could be left empty but we are
# currently using it to provide the morphosyntactic information in a form that
# the users of the Czech PDT will be familiar with (even though many feature
# values will not be visible in a Czech tag).
#------------------------------------------------------------------------------
sub set_pdt_tag
{
    my $self = shift;
    my $node = shift;
    my $f = $node->iset();
    log_fatal("Undefined interset feature structure") if(!defined($f));
    my $pdt_tag = encode('cs::pdt', $f);
    $node->set_tag($pdt_tag);
}



#------------------------------------------------------------------------------
# Sets the universal POS tag to the tag attribute, based on Interset.
#------------------------------------------------------------------------------
sub set_upos_tag
{
    my $self = shift;
    my $node = shift;
    my $f = $node->iset();
    log_fatal("Undefined interset feature structure") if(!defined($f));
    my $upos = $f->get_upos();
    $node->set_tag($upos);
}



#------------------------------------------------------------------------------
# Certain nodes in some treebanks have empty lemmas, although there are lemmas
# in the particular treebank in general. For instance, numbers and punctuation
# symbols in PADT 2.0 lack lemmas. This function makes sure that the lemma
# attribute does not stay empty.
#------------------------------------------------------------------------------
sub fill_in_lemmas
{
    my $self   = shift;
    my $root   = shift;
    foreach my $node ( $root->get_descendants() )
    {
        if(!defined($node->lemma()) || $node->lemma() eq '')
        {
            # Sometimes even the word form is empty. Either it's a bug or these are NULL nodes that also occur in other treebanks.
            if(!defined($node->form()) || $node->form() eq '')
            {
                $node->set_form('<NULL>');
                $node->set_lemma('<NULL>');
            }
            # If there are other instances than numbers and punctuation, we want to know about them.
            elsif($node->iset()->pos() =~ m/^(num|punc)$/)
            {
                $node->set_lemma($node->form());
            }
        }
    }
}



#------------------------------------------------------------------------------
# Convert dependency relation tags to the harmonized label set. The method must
# be overridden in order to produce valid deprels.
#
# List and description of analytical functions in PDT 2.0:
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
# (Note that the HamleDT 2.0 label set is a modification of the PDT set, and
# that we may use temporarily other labels that will disappear once the tree
# structure is successfully transformed.)
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
        $node->set_deprel($deprel);
    }
}



#------------------------------------------------------------------------------
# A method to target known annotation errors (these could be batches of
# automatically identifiable guideline violations but often it is just a single
# point in the data; if we cannot fix the source data, this will ensure that
# any conversion we produce is fixed). This method will be called right after
# converting the deprels to the harmonized label set, but before any tree
# transformations. This ancestor implementation is empty; the real errors must
# be defined for each harmonized treebank separately.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    return 1;
}



#------------------------------------------------------------------------------
# Assigns default afuns. To be used if a node does not have a valid afun value
# and we cannot tell anything more precise about the node.
#------------------------------------------------------------------------------
sub set_default_afun
{
    my $self = shift;
    my $node = shift;
    my $afun;
    my $parent = $node->parent();
    if($parent->is_root())
    {
        # A verb attached directly to root is predicate.
        # There could also be coordination of verbal predicates (possibly nested coordination) but we do not check it at the moment. ###!!!
        if($node->is_verb())
        {
            $afun = 'Pred';
        }
        else
        {
            $afun = 'ExD';
        }
    }
    else
    {
        # Nominal nodes are modified by attributes, verbal nodes by objects or adverbials.
        # (Adverbials are default because there are typically fewer constraints on them.)
        # Again, we do not check whether the parent is a coordination of verbs. ###!!!
        if($parent->is_verb())
        {
            $afun = 'Adv';
        }
        else
        {
            $afun = 'Atr';
        }
    }
    $node->set_afun($afun);
}



#------------------------------------------------------------------------------
# Sets the real function of the subtree. If its current deprel is AuxP or AuxC,
# finds the first descendant with a real deprel and replaces it. If this is
# a coordination or apposition root, finds all the members and replaces their
# deprels (but note that members of the same coordination can differ in deprels
# if some of them have 'ExD'; this method can only set the same deprel for
# all).
#
# This method is adapted from Treex::Core::Node::A->set_real_afun(). We need it
# to work with deprels instead of afuns. And we do not want to have an
# analogous method set_real_deprel() in Treex::Core::Node::A because deprels
# are more general than afuns and we should not assume the special meaning of
# the values Coord|Apos|AuxP|AuxC globally.
#------------------------------------------------------------------------------
sub set_real_deprel
{
    my $self = shift;
    my $node = shift;
    my $new_deprel = shift;
    my $warnings = shift;
    my $deprel = $node->deprel();
    if ( not defined($deprel) )
    {
        $deprel = '';
    }
    if ( $deprel =~ m/^Aux[PC]$/ )
    {
        my @children = $node->children();
        # Exclude punctuation children (deprel-wise, not POS-tag-wise: we do not want to exclude coordination heads).
        @children = grep {$_->deprel() !~ m/^Aux[XGK]$/} (@children);
        my $n = scalar(@children);
        if ( $n < 1 )
        {
            if ($warnings)
            {
                my $i_sentence = $node->get_bundle()->get_position() + 1;    # tred numbers from 1
                my $form       = $node->form();
                log_warn("$deprel node does not have children (sentence $i_sentence, '$form')");
            }
        }
        else
        {
            if ( $warnings && $n > 1 )
            {
                my $i_sentence = $node->get_bundle()->get_position() + 1;    # tred numbers from 1
                my $form       = $node->form();
                log_warn("$deprel node has $n children so it is not clear which one bears the real deprel (sentence $i_sentence, '$form')");
            }
            foreach my $child (@children)
            {
                $self->set_real_deprel($child, $new_deprel, $warnings);
            }
            return $deprel;
        }
    }
    elsif ( $deprel =~ m/^(Coord|Apos)$/ )
    {
        my @members = grep {$_->is_member()} ($node->children());
        my $n = scalar(@members);
        if ( $n < 1 )
        {
            if ($warnings)
            {
                my $i_sentence = $node->get_bundle()->get_position() + 1;    # tred numbers from 1
                my $form       = $node->form();
                log_warn("$deprel does not have members (sentence $i_sentence, '$form')");
            }
        }
        else
        {
            foreach my $member (@members)
            {
                $self->set_real_deprel($member, $new_deprel, $warnings);
            }
            return $deprel;
        }
    }
    # This is a normal node (i.e. not Coord|Apos|AuxP|AuxC), which can receive its own label.
    # Special value PredOrExD is for nodes / constructions directly under the root node.
    # It should be resolved to either Pred or ExD, depending on whether the node is or is not a verb.
    if($new_deprel eq 'PredOrExD')
    {
        $node->set_deprel($node->is_verb() ? 'Pred' : 'ExD');
    }
    else
    {
        $node->set_deprel($new_deprel);
    }
    return $deprel;
}



#------------------------------------------------------------------------------
# After all transformations all nodes must have valid deprels (not our pseudo-
# deprels). Report cases breaching this rule so that we can easily find them in
# Ttred. This function allows only deprels that are part of the HamleDT label
# set. Special Prague labels for Arabic and Tamil may be excluded. On the other
# hand, new labels may have been introduced to HamleDT, e.g. "Neg".
#------------------------------------------------------------------------------
sub check_deprels
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->deprel();
        if ( defined($deprel) &&
             $deprel !~ m/^(Pred|Sb|Obj|Pnom|Adv|Atr|Atv|AtvV|ExD|Coord|Apposition|Aux[APCVTOYXZGKR]|Neg|NR)$/           )
        {
            log_warn($node->get_address());
            $self->log_sentence($root);
            my $ord    = $node->ord();
            my $form   = $node->form();
            my $tag    = $node->tag();
            # This cannot be fatal if we want the trees to be saved and examined in Tred.
            if ($deprel)
            {
                log_warn("Node $ord:$form/$tag/$deprel still has the deprel $deprel, invalid in HamleDT.");
                # Erase the pseudo-deprel to avoid further complaints of Treex and Tred.
                log_info("Removing the invalid deprel...");
                $node->set_deprel('NR');
            }
            else
            {
                log_warn("Node $ord:$form/$tag/$deprel still has no deprel.");
                $node->set_deprel('NR');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Shifts afun from preposition (subordinating conjunction) to its argument and
# gives the preposition (conjunction) new afun 'AuxP' ('AuxC'). Useful for
# treebanks where prepositions and subordinating conjunctions bear the deprel
# of their subtree. The subclass should not call this method before it assigns
# afuns to all nodes and before it converts coordination. Arguments of
# prepositions (subordinating conjunctions) must have the afun 'PrepArg'
# ('SubArg'). There should be just one child with such afun.
#------------------------------------------------------------------------------
sub process_prep_sub_arg_cloud
{
    my $self = shift;
    my $root = shift;
    # Convert the tree of nodes to tree of clouds, i.e. build the parallel structure.
    my $cloud = Treex::Core::Cloud->new();
    $cloud->create_from_node($root);
    # Traverse the tree of clouds.
    $self->process_prep_sub_arg_cloud_recursive($cloud);
    $cloud->destroy_children();
}
sub process_prep_sub_arg_cloud_recursive
{
    my $self                = shift;
    my $cloud               = shift;
    my $parent_current_afun = shift;
    my $parent_new_afun     = $parent_current_afun;
    my $current_afun        = $cloud->afun();
    $current_afun = '' if(!defined($current_afun));

    # If I am currently a prep/sub argument, let's steal the parent's afun.
    if ( $current_afun eq 'PrepArg' )
    {
        $current_afun    = $parent_current_afun;
        $parent_new_afun = 'AuxP';
    }
    elsif ( $current_afun eq 'SubArg' )
    {
        $current_afun    = $parent_current_afun;
        $parent_new_afun = 'AuxC';
    }

    # Now let's see whether my children want my afun.
    my $new_afun = $current_afun;
    # Recursion that traverses the whole tree means that we go to both participants and modifiers.
    # But we cannot work with both the same way.
    # We cannot compare participants' afun with the afun of the coordination cloud: they should be identical!
    my @children = $cloud->get_shared_modifiers();
    my @participants = $cloud->get_participants();
    my $argument_found = 0;
    foreach my $child (@children)
    {

        # Ask a child if it wants my afun and what afun it thinks I should get.
        # A preposition can have more than one child and some of the children may not be PrepArgs.
        # So only set $new_afun if it really differs from $current_afun
        # (otherwise the first child could propose a change and the second could revert it).
        my $suggested_afun = $self->process_prep_sub_arg_cloud_recursive( $child, $current_afun );
        if($suggested_afun ne $current_afun)
        {
            # Even if the preposition has several children, only one can be PrepArg.
            # Otherwise it would not be clear what to do.
            # (Note however that there is no warranty that the input data is clean.)
            if($argument_found)
            {
                log_warn("Two or more Prep/SubArg children under one preposition/conjunction.");
            }
            $new_afun = $suggested_afun;
            $argument_found = 1;
        }
    }
    foreach my $participant (@participants)
    {
        # A non-trivial cloud, e.g. coordination, cannot accept AuxP suggestions from its participants.
        # In particular, coordination should have the same afun as most if not all its conjuncts.
        # We will recurse to participants so that anything within their subtrees can be processed
        # but we will ignore their suggestions going back up.
        my $ignored_suggestion = $self->process_prep_sub_arg_cloud_recursive($participant, $parent_current_afun);
    }
    # Set the afun my children selected (it is either my current afun or 'AuxP' or 'AuxC').
    $cloud->set_afun($new_afun);

    # Let the parent know what I selected for him.
    return $parent_new_afun;
}



#------------------------------------------------------------------------------
# Examines the last node of the sentence. If it is a punctuation, makes sure
# that it is attached to the artificial root node. We deviate here from PDT.
# In PDT, if there is a quotation mark after sentence-terminating period, they
# attach it non-projectively to the main predicate. We remove the non-
# projectivity and attach the quotation mark directly to the root. It is in
# line with the rule that quotation marks should be attached to the root of the
# stuff inside.
#------------------------------------------------------------------------------
sub attach_final_punctuation_to_root
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    # Rule 0: If the last token is Coord or Apos, do not touch anything!
    # - later we may want to check such coordination but we must take extra care not to make the structure invalid.
    # Rule 1: If the last token (or sequence of tokens) is
    # - a period ('.') or three dots ('...' or the corresponding Unicode character) or devanagari danda
    # - question or exclamation mark ('?', '!', Arabic question mark)
    # - semicolon, colon, comma or dash (';', ':', ',', '-', Arabic semicolon or comma, Unicode dashes)
    # - any combination of the above
    # => then all these nodes are attached directly to the root.
    # => comma is AuxX, anything else is AuxK
    # Rule 2: If the last token (or sequence of tokens) is
    # - single or double quotation mark ("ASCII", ``Penn-style'', or Unicode)
    # - and if it is preceded by anything matching Rule 1
    # => then it is attached to the root and labeled AuxG
    # => the preceding punctuation is treated according to Rule 1
    # - note that we currently do not attempt to find out whether the corresponding initial quotation mark is present
    # - (normally we want to know whether quotation marks are paired)
    # - also note that if there are tokens matching Rule 1 after the quotation mark, then the quotation mark is not affected by this function at all
    #   and other methods that normalize punctuation inside the sentence will apply
    # Note that nothing happens if the final token is a bracket, a slash or a less common symbol.
    my $rule1chars = '[-\.\x{2026}\x{964}\x{965}?!\x{61F};:,\x{61B}\x{60C}\x{2010}-\x{2015}]';
    my $rule2chars = '["`'."'".'\x{2018}-\x{201F}]';
    # Try rule 2 first (rule 1 will have to be checked anyway).
    my $rule1 = 0;
    my $rule2 = 0;
    my $rule1i0;
    my $rule2i0;
    my $rule1i1 = $#nodes;
    my $i = $#nodes;
    # Do not touch the last node if it heads coordination or apposition.
    return if($i>=0 && $nodes[$i]->deprel()  && $nodes[$i]->deprel() =~ m/^(Coord|Apos)$/);
    while($i>=0 && $nodes[$i]->form() =~ m/^$rule2chars+$/)
    {
        $rule2 = 1;
        $rule2i0 = $i;
        $i--;
    }
    # Do not touch the last node if it heads coordination or apposition.
    return if($i>=0 && $nodes[$i]->deprel() && $nodes[$i]->deprel() =~ m/^(Coord|Apos)$/);
    while($i>=0 && $nodes[$i]->form() =~ m/^$rule1chars+$/)
    {
        $rule1 = 1;
        $rule1i0 = $i;
        $i--;
    }
    # Do not touch the last node if it heads coordination or apposition.
    return if(defined($rule1i0) && $rule1i0>=0 && $rule1i0<=$#nodes && $nodes[$rule1i0]->deprel() && $nodes[$rule1i0]->deprel() =~ m/^(Coord|Apos)$/);
    if($rule2 && $rule1)
    {
        $rule1i1 = $rule2i0-1;
        for(my $i = $rule2i0; $i<=$#nodes; $i++)
        {
            $nodes[$i]->set_parent($root);
            $nodes[$i]->set_deprel('AuxG');
            # Even though some treebanks think otherwise, final punctuation marks are neither conjunctions nor conjuncts.
            delete($nodes[$i]->wild()->{conjunct});
            delete($nodes[$i]->wild()->{coordinator});
            $nodes[$i]->set_is_member(undef);
            # Sentence-terminating punctuation should be a leaf node.
            # If it governs anything it should be probably reattached to the root.
            foreach my $child ($nodes[$i]->children())
            {
                $child->set_parent($root);
                $self->set_real_deprel($child, 'PredOrExD');
            }
        }
    }
    if($rule1)
    {
        for(my $i = $rule1i0; $i<=$rule1i1; $i++)
        {
            $nodes[$i]->set_parent($root);
            if($nodes[$i]->form() =~ m/^,\x{60C}$/)
            {
                $nodes[$i]->set_deprel('AuxX');
            }
            else
            {
                $nodes[$i]->set_deprel('AuxK');
            }
            delete($nodes[$i]->wild()->{conjunct});
            delete($nodes[$i]->wild()->{coordinator});
            $nodes[$i]->set_is_member(undef);
            # Sentence-terminating punctuation should be a leaf node.
            # If it governs anything it should be probably reattached to the root.
            foreach my $child ($nodes[$i]->children())
            {
                $child->set_parent($root);
                $self->set_real_deprel($child, 'PredOrExD');
            }
        }
    }
}



#------------------------------------------------------------------------------
# Recursively search for coordinations and solve them immediately, i.e. don't
# collect all first. Use the Coordination object.
#------------------------------------------------------------------------------
sub shape_coordination_recursively
{
    my $self  = shift;
    my $root  = shift;
    my $debug = shift;
    my $coordination = new Treex::Core::Coordination;
    my @recursion = $self->detect_coordination($root, $coordination, $debug);
    if(scalar($coordination->get_conjuncts())>0)
    {
        log_info('COORDINATION FOUND') if ($debug);
        # We have found coordination! Solve it right away.
        $coordination->shape_prague();
        # Call recursively on all descendants. (The exact recursive set depends on annotation style.
        # We got it from detect_coordination().)
        foreach my $node (@recursion)
        {
            $self->shape_coordination_recursively($node, $debug);
        }
    }
    # Call recursively on all children if no coordination detected now.
    else
    {
        foreach my $child ($root->children())
        {
            $self->shape_coordination_recursively($child, $debug);
        }
    }
}



#------------------------------------------------------------------------------
# This method is called for coordination and apposition nodes whose members do
# not have the is_member attribute set (e.g. in Arabic and Slovene treebanks
# the information was lost in conversion to CoNLL). It estimates, based on
# deprels, which children are members and which are shared modifiers.
#------------------------------------------------------------------------------
sub identify_coap_members
{
    my $self = shift;
    my $coap = shift;
    return unless($coap->deprel() =~ m/^(Coord|Apos)$/);
    # We should not estimate coap membership if it is already known!
    foreach my $child ($coap->children())
    {
        if($child->is_member())
        {
            log_warn('Trying to estimate CoAp membership of a node that is already marked as member.');
        }
    }
    # Get the list of nodes involved in the structure.
    my @involved = $coap->get_children({'ordered' => 1, 'add_self' => 1});
    # Get the list of potential members and modifiers, i.e. drop delimiters.
    # Note that there may be more than one Coord|Apos node involved if there are nested structures.
    # We simplify the task by assuming (wrongly) that nested structures are always members and never modifiers.
    # Delimiters can have the following deprels:
    # Coord|Apos ... the root of the structure, either conjunction or punctuation
    # AuxY ... other conjunction
    # AuxX ... comma
    # AuxG ... other punctuation
    my @memod = grep {$_->deprel() !~ m/^Aux[GXY]$/ && $_!=$coap} (@involved);
    # If there are only two (or fewer) candidates, consider both members.
    if(scalar(@memod)<=2)
    {
        foreach my $m (@memod)
        {
            $m->set_is_member(1);
        }
    }
    else
    {
        # Hypothesis: all members typically have the same deprel.
        # Find the most frequent deprel among candidates.
        # For the case of ties, remember the first occurrence of each deprel.
        # Do not count nested 'Coord' and 'Apos': these are jokers substituting any member deprel.
        # Same for 'ExD': these are also considered members (in fact they are children of an ellided member).
        my %count;
        my %first;
        foreach my $m (@memod)
        {
            my $deprel = defined($m->deprel()) ? $m->deprel() : '';
            next if($deprel =~ m/^(Coord|Apos|ExD)$/);
            $count{$deprel}++;
            $first{$deprel} = $m->ord() if(!exists($first{$deprel}));
        }
        # Get the winning deprel.
        my @deprels = sort
        {
            my $result = $count{$b} <=> $count{$a};
            unless($result)
            {
                $result = $first{$a} <=> $first{$b};
            }
            return $result;
        }
        (keys(%count));
        # Note that there may be no specific winning deprel if all candidate deprels were Coord|Apos|ExD.
        my $winner = @deprels ? $deprels[0] : '';
        ###!!! If the winning deprel is 'Atr', it is possible that some Atr nodes are members and some are shared modifiers.
        ###!!! In such case we ought to check whether the nodes are delimited by a delimiter.
        ###!!! This has not yet been implemented.
        foreach my $m (@memod)
        {
            my $deprel = defined($m->deprel()) ? $m->deprel() : '';
            if($deprel eq $winner || $deprel =~ m/^(Coord|Apos|ExD)$/)
            {
                $m->set_is_member(1);
            }
        }
    }
}



#------------------------------------------------------------------------------
# Catches possible annotation inconsistencies. If there are no conjuncts under
# a Coord node, let's try to find them.
#------------------------------------------------------------------------------
sub check_coord_membership
{
    my $self  = shift;
    my $root  = shift;
    # The root never heads coordination.
    foreach my $node ($root->children())
    {
        $node->set_is_member(undef);
    }
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if ($node->is_coap_root() && ! grep {$_->is_member()} ($node->children()))
        {
            $self->identify_coap_members($node);
        }
    }
}



#------------------------------------------------------------------------------
# Conjunction (such as 'and', 'but') occurring as the first word of the
# sentence should be analyzed as deficient coordination whose only member is
# the main verb of the main clause.
#------------------------------------------------------------------------------
sub mark_deficient_clausal_coordination
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants( { ordered => 1 } );
    if ( $nodes[0]->afun() eq 'Coord' && scalar($nodes[0]->get_coap_members())==0 )
    {
        my $croot = $nodes[0];
        my @root_children = $root->children();
        # Do not reattach $croot earlier because it must not be one of @root_children.
        # Do not reattach it later because Treex might complain about cycles.
        $croot->set_parent($root);
        foreach my $rc (@root_children)
        {
            next if($rc==$croot);
            # The sentence-final punctuation must stay at the upper level.
            next if($rc->afun() eq 'AuxK');
            $rc->set_parent($croot);
            $rc->set_is_member(1) unless($rc->afun() =~ m/^Aux[GXY]$/);
        }
        # It is not guaranteed that $croot now has coordination members.
        # If we were not able to find nodes elligible as members, we must not tag $croot as Coord.
        if(scalar($croot->get_coap_members())==0)
        {
            $croot->set_afun('ExD');
        }
    }
}



#------------------------------------------------------------------------------
# Validates coordination/apposition structures.
# - A Coord/Apos node must have at least one member.
# - A node with is_member set must have a Coord/Apos parent.
# - Note that is_member is now set directly under the Coord/Apos node,
#   regardless of prepositions and subordinating conjunctions.
# - Members should not have afuns AuxX (comma), AuxG (other punctuation) and
#   AuxY (other words, e.g. parts of multi-word coordinating conjunction).
#------------------------------------------------------------------------------
sub validate_coap
{
    my $self = shift;
    my $node = shift;
    my $afun = $node->afun();
    my @children = $node->get_children();
    if($afun =~ m/^(Coord|Apos)$/ && !grep {$_->is_member()} (@children))
    {
        $self->log_sentence($node);
        log_warn("The $afun node #".$node->ord()." '".$node->form()."' is missing coap members.");
    }
    if($node->is_member())
    {
        if($node->parent()->afun() !~ m/^(Coord|Apos)$/)
        {
            $self->log_sentence($node);
            log_warn("The member node #".$node->ord()." '".$node->form()."' does not have a coap parent.");
        }
        if($afun =~ m/^Aux[GXY]$/)
        {
            $self->log_sentence($node);
            log_warn("The node #".$node->ord()." '".$node->form()."' should be either coap member or $afun but not both.");
        }
    }
    foreach my $child (@children)
    {
        $self->validate_coap($child);
    }
}



#------------------------------------------------------------------------------
# Error handler: removes 'is_member' attribute if the node is not
# part of the coordination structure.
#------------------------------------------------------------------------------
sub remove_ismember_membership
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if ($node->is_member)
        {
            my $parnode = $node->get_parent();
            if (defined $parnode)
            {
                my $pardeprel = $parnode->deprel();
                if (defined($pardeprel) && $pardeprel !~ /^(Coord|Apos)$/)
                {
                    $node->set_is_member(undef);
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Some treebanks attach subordinating conjunctions to predicates of subordinate
# clauses. This method makes them govern the predicates, as in PDT. Other
# children of the predicate remain attached to the predicate. Exception: comma.
#------------------------------------------------------------------------------
sub raise_subordinating_conjunctions
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'AuxC' && $node->is_leaf() && !$node->is_member())
        {
            my $parent = $node->parent();
            # Multi-word AuxC should have all but the last word as leaves. Skip dependent parts of AuxC MWE.
            unless($parent->is_root() || $parent->deprel() eq 'AuxC')
            {
                my $grandparent = $parent->parent();
                # Is there a left neighbor and is it a comma?
                my $ln = $node->get_left_neighbor();
                my $comma = $ln && $ln->deprel() eq 'AuxX' ? $ln : undef;
                if($comma)
                {
                    $comma->set_parent($node);
                }
                $node->set_parent($grandparent);
                $parent->set_parent($node);
                # Both conjunction and its former parent keep their afuns but the is_member flag must be moved.
                $node->set_is_member($parent->is_member());
                $parent->set_is_member(0);
            }
        }
    }
}



#------------------------------------------------------------------------------
# Swaps node with its parent. The original parent becomes a child of the node.
# All other children of the original parent become children of the node. The
# node also keeps its original children.
#
# The lifted node gets the afun of the original parent while the original
# parent gets a new afun. The conll_deprel attribute is changed, too, to
# prevent possible coordination destruction.
#
# If the original parent had is_member set, the flag will be moved to the
# lifted node. If the lifted node had is_member set, we must lift the whole
# coordination! If the original parent is Coord and the lifted node is a shared
# modifier of coordination, we must be careful with reattaching the original
# siblings of the lifted node. Only other shared modifiers can be reattached.
#------------------------------------------------------------------------------
sub lift_node
{
    my $self   = shift;
    my $node   = shift;
    my $afun   = shift;             # new afun for the old parent
    my $parent = $node->parent();
    confess('Cannot lift a child of the root') if ( $parent->is_root() );
    my $grandparent = $parent->parent();

    # Lifting a conjunct means lifting the whole coordination!
    unless($node->is_member())
    {
        # Reattach myself to the grandparent.
        $node->set_parent($grandparent);
        # If parent is coordination, we need the afun of the conjuncts.
        $node->set_afun($parent->get_real_afun());
        $node->set_is_member( $parent->is_member() );
        $node->set_conll_deprel( $parent->conll_deprel() );
        # Reattach all previous siblings to myself.
        foreach my $sibling ( $parent->children() )
        {
            # No need to test whether $sibling==$node as we already reattached $node.
            # If parent is Coord, reattach modifiers but not conjuncts!
            unless($parent->deprel() eq 'Coord' && ($sibling->is_member() || $sibling->deprel() =~ m/^Aux[GXY]$/))
            {
                $sibling->set_parent($node);
            }
        }
        # Reattach the previous parent to myself.
        $parent->set_parent($node);
        # If parent is coordination, we must set afun of its conjuncts.
        $parent->set_real_afun($afun); ##############!!!!!!!!!!!!!!!!!!!!!!!!!!!!! jenže my teď místo afunů pracujeme s deprely!
        $parent->set_is_member(0);
        $parent->set_conll_deprel('');
    }
    else # lift coordination
    {
        my $coordination = new Treex::Core::Coordination;
        $coordination->detect_prague($parent);
        # Now redefine parent and grandparent to those of the whole coordination.
        my $coordroot = $parent;
        $parent = $grandparent;
        confess('Cannot lift a child of the root') if ( $parent->is_root() );
        $grandparent = $parent->parent();
        # Reattach coordination to the grandparent.
        $coordination->set_parent($grandparent);
        # If parent is coordination, we need the afun of the conjuncts.
        $coordination->set_afun($parent->get_real_afun());
        $coordroot->set_is_member($parent->is_member());
        # Reattach all previous siblings to myself.
        foreach my $sibling ($parent->children())
        {
            unless($sibling==$coordroot)
            {
                # If parent is Coord, reattach modifiers but not conjuncts!
                unless($parent->afun() eq 'Coord' && ($sibling->is_member() || $sibling->afun() =~ m/^Aux[GXY]$/))
                {
                    $coordination->add_shared_modifier($sibling);
                }
            }
        }
        # Reattach the previous parent to myself.
        $coordination->add_shared_modifier($parent);
        # If parent is coordination, we must set afun of its conjuncts.
        $parent->set_real_afun($afun);
        $parent->set_is_member(0);
        $parent->set_conll_deprel('');
        $coordination->shape_prague();
    }
}



#------------------------------------------------------------------------------
# Writes the current sentence including the sentence number to the log. To be
# used together with warnings so that the problematic sentence can be localized
# and examined in Ttred.
#------------------------------------------------------------------------------
sub log_sentence
{
    my $self = shift;
    my $node = shift;
    my $root = $node->get_root();

    # get_position() returns numbers from 0 but Tred numbers sentences from 1.
    my $i = $root->get_bundle()->get_position() + 1;
    log_info( "\#$i " . $root->get_zone()->sentence() );
}



#------------------------------------------------------------------------------
# Returns 1 if the sentence of a given node contains a given substring (mind
# tokenization). Returns 0 otherwise. Can be used to easily focus debugging on
# a problematic sentence like this:
# $debug = $self->sentence_contains($node, 'sondern auch mit Instrumenten');
#------------------------------------------------------------------------------
sub sentence_contains
{
    my $self     = shift;
    my $node     = shift;
    my $query    = shift;
    my $sentence = $node->get_zone()->sentence();
    return $sentence =~ m/$query/;
}



1;

=over

=item Treex::Block::HamleDT::Harmonize

Common methods for treebank-specific blocks that transform trees from the
various annotation styles to the style of HamleDT (Prague).

The analytical functions (afuns) need to be guessed from C<conll/deprel> and
other sources of information. The tree structure must be transformed at places
(e.g. there are various styles of capturing coordination).

Morphological tags should be decoded into Interset. Then the C<tag> attribute
should be set to the PDT 15-character positional tag matching the Interset
features.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
