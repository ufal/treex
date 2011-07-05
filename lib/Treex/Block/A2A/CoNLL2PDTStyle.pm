package Treex::Block::A2A::CoNLL2PDTStyle;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';
use tagset::common;
use tagset::cs::pdt;



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
    my $self = shift;
    my $zone = shift;
    my $tagset = shift; # optional argument from the subclass->process_zone()
    # Copy the original dependency structure before adjusting it.
    $self->backup_zone($zone);
    my $a_root  = $zone->get_atree();
    # Convert CoNLL POS tags and features to Interset and PDT if possible.
    $self->convert_tags($a_root, $tagset);
    # Conversion from dependency relation tags to afuns (analytical function tags) must be done always
    # and it is almost always treebank-specific (only a few treebanks use the same tagset as the PDT).
    $self->deprel_to_afun($a_root);
    # Adjust the tree structure. Some of the methods are general, some will be treebank-specific.
    # The decision whether to apply a method at all is always treebank-specific.
    #$self->attach_final_punctuation_to_root($a_root);
    #$self->process_auxiliary_particles($a_root);
    #$self->process_auxiliary_verbs($a_root);
    #$self->restructure_coordination($a_root);
    #$self->mark_deficient_clausal_coordination($a_root);
    # The return value can be used by the overriding methods of subclasses.
    return $a_root;
}



#------------------------------------------------------------------------------
# Copies the original zone so that the user can compare the original and the
# restructured tree in TTred.
#------------------------------------------------------------------------------
sub backup_zone
{
    my $self = shift;
    my $zone0 = shift;
    return $zone0->copy('orig');
}



#------------------------------------------------------------------------------
# Converts tags of all nodes to Interset and PDT tagset.
#------------------------------------------------------------------------------
sub convert_tags
{
    my $self = shift;
    my $root = shift;
    my $tagset = shift; # optional, see below
    foreach my $node ($root->get_descendants())
    {
        $self->convert_tag($node, $tagset);
    }
}



#------------------------------------------------------------------------------
# Decodes the part-of-speech tag and features from a CoNLL treebank into
# Interset features. Stores the features with the node. Then sets the tag
# attribute to the closest match in the PDT tagset.
#------------------------------------------------------------------------------
sub convert_tag
{
    my $self = shift;
    my $node = shift;
    my $tagset = shift; # optional tagset identifier (default = 'conll'; sometimes we need 'conll2007' etc.)
    $tagset = 'conll' unless($tagset);
    # Note that the following hack will not work for all treebanks.
    # Some of them use tagsets not called '*::conll'.
    # Many others are not covered by DZ Interset yet.
    # tagset::common::find_drivers() could help but it would not be efficient to call it every time.
    # Instead, every subclass of this block must know whether to call convert_tag() or not.
    # List of CoNLL tagsets covered by 2011-07-05:
    my @known_drivers = qw(ar::conll ar::conll2007 bg::conll cs::conll cs::conll2009 da::conll de::conll de::conll2009 en::conll en::conll2009 pt::conll sv::conll zh::conll);
    my $driver = $node->get_zone()->language().'::'.$tagset;
    return unless(grep {$_ eq $driver} (@known_drivers));
    # Current tag is probably just a copy of conll_pos.
    # We are about to replace it by a 15-character string fitting the PDT tagset.
    my $conll_cpos = $node->conll_cpos;
    my $conll_pos = $node->conll_pos;
    my $conll_feat = $node->conll_feat;
    my $conll_tag = "$conll_cpos\t$conll_pos\t$conll_feat";
    my $f = tagset::common::decode($driver, $conll_tag);
    my $pdt_tag = tagset::cs::pdt::encode($f, 1);
    $node->set_iset($f);
    $node->set_tag($pdt_tag);
}



#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# This abstract class does not understand the source-dependent CoNLL deprels,
# so it only copies them to afuns. The method must be overriden in order to
# produce valid afuns.
#
# List and description of analytical functions in PDT 2.0:
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $deprel = $node->conll_deprel();
        $node->set_afun($deprel);
    }
}



#------------------------------------------------------------------------------
# Examines the last node of the sentence. If it is a punctuation, makes sure
# that it is attached to the artificial root node.
#------------------------------------------------------------------------------
sub attach_final_punctuation_to_root
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    my $fnode = $nodes[$#nodes];
    my $final_pos = $fnode->get_iset('pos');
    if($final_pos eq 'punc')
    {
        $fnode->set_parent($root);
        $fnode->set_afun('AuxK');
    }
}



#------------------------------------------------------------------------------
# Restructures coordinations to the Prague style.
# Calls a treebank-specific method detect_coordination() that fills a list of
# arrays, each containing a hash with the following keys:
# - members: list of nodes that are members of coordination
# - delimiters: list of nodes with commas or conjunctions between the members
# - shared_modifiers: list of nodes that depend on the whole coordination
# - parent: the node the coordination modifies
# - afun: the analytical function of the whole coordination wrt. its parent
#------------------------------------------------------------------------------
sub restructure_coordination
{
    my $self = shift;
    my $root = shift;
    my @coords;
    # Collect information about all coordination structures in the tree.
    $self->detect_coordination($root, \@coords);
    # Loop over coordinations and restructure them.
    # Hopefully the order in which the coordinations are processed is not significant.
    foreach my $c (@coords)
    {
        ###!!! DEBUG
        #my @cnodes = sort {$a->ord() <=> $b->ord()} (@{$c->{members}}, @{$c->{delimiters}});
        #log_info(join(' ', map {$_->ord().':'.$_->form()} (@cnodes)));
        ###!!! END OF DEBUG
        my $parent = $c->{parent};
        my $afun = $c->{afun} or '';
        # Select the last delimiter as the new root.
        if(!@{$c->{delimiters}})
        {
            # In fact, there is an error in the CoNLL 2007 data where this happens (the conjunction is mistakenly tagged as conjarg).
            # We have to skip such cases but we do not want to make it fatal unless we are debugging this module.
            my $debug = 0;
            if($debug)
            {
                $self->log_sentence($root);
                log_info("Coordination members:    ".join(' ', map {$_->form()} (@{$c->{members}})));
                log_info("Coordination delimiters: ".join(' ', map {$_->form()} (@{$c->{delimiters}})));
                log_info("Coordination modifiers:  ".join(' ', map {$_->form()} (@{$c->{shared_modifiers}})));
                log_fatal("Coordination has no delimiters. What node shall I make the new coordination root?");
            }
            else
            {
                return;
            }
        }
        my $croot = pop(@{$c->{delimiters}});
        # Attach the new root to the parent of the coordination.
        $croot->set_parent($parent);
        $croot->set_afun('Coord');
        # Attach all coordination members to the new root.
        foreach my $member (@{$c->{members}})
        {
            $member->set_parent($croot);
            $member->set_is_member(1);
            my $preparg;
            if($member->get_iset('pos') eq 'prep' && defined($preparg = $self->get_preposition_argument($member)))
            {
                $member->set_afun('AuxP');
                $preparg->set_afun($afun);
            }
            else
            {
                $member->set_afun($afun);
            }
        }
        # Attach all remaining delimiters to the new root.
        foreach my $delimiter (@{$c->{delimiters}})
        {
            $delimiter->set_parent($croot);
            if($delimiter->form() eq ',')
            {
                $delimiter->set_afun('AuxX');
            }
            elsif($delimiter->get_iset('pos') =~ m/^(conj|adv|part)$/)
            {
                $delimiter->set_afun('AuxY');
            }
            else
            {
                $delimiter->set_afun('AuxG');
            }
        }
        # Attach all shared modifiers to the new root.
        foreach my $modifier (@{$c->{shared_modifiers}})
        {
            $modifier->set_parent($croot);
        }
    }
}



#------------------------------------------------------------------------------
# Returns the noun phrase attached directly to the preposition in a
# prepositional phrase. It is difficult to detect without understanding the
# treebank-specific dependency relation tags because the preposition may have
# more than one child (coordination members if the preposition governed
# a coordination; modifiers (intensifiers) of the whole PP if the guidelines
# rule to attach them to the preposition) and the main child need not be
# necessarily a noun (it could be an adjective, a numeral etc.)
#------------------------------------------------------------------------------
sub get_preposition_argument
{
    my $self = shift;
    my $prepnode = shift;
    # The assumption is that the preposition governs the noun phrase and not vice versa.
    # If not, run the corresponding transformation prior to calling this method.
    # We cannot reliably assume that a preposition has only one child.
    # There may be rhematizers modifying the whole prepositional phrase.
    # We assume that the real argument of the preposition can only have one of selected parts of speech and afuns.
    # (Note that PrepArg is a pseudo-afun that is not defined in PDT but subclasses can use it to explicitly mark preposition arguments
    # whenever no other suitable afun is readily available.)
    my @prepchildren = grep {$_->afun() eq 'PrepArg'} ($prepnode->children());
    if(@prepchildren)
    {
        if(scalar(@prepchildren)>1)
        {
            $self->log_sentence($prepnode);
            log_info("Preposition ".$prepnode->ord().":".$prepnode->form());
            log_warn("More than one preposition argument.");
        }
        return $prepchildren[0];
    }
    else
    {
        @prepchildren = grep {$_->get_iset('pos') =~ m/^(noun|adj|num)$/} ($prepnode->children());
        if(@prepchildren)
        {
            if(scalar(@prepchildren)>1)
            {
                $self->log_sentence($prepnode);
                log_info("Preposition ".$prepnode->ord().":".$prepnode->form());
                log_warn("More than one preposition argument.");
            }
            return $prepchildren[0];
        }
        else
        {
            @prepchildren = grep {$_->afun() =~ m/^(Sb|Obj|Pnom|Adv|Atv|Atr)$/} ($prepnode->children());
            if(@prepchildren)
            {
                if(scalar(@prepchildren)>1)
                {
                    $self->log_sentence($prepnode);
                    log_info("Preposition ".$prepnode->ord().":".$prepnode->form());
                    log_warn("More than one preposition argument.");
                }
                return $prepchildren[0];
            }
        }
    }
    return undef;
}



#------------------------------------------------------------------------------
# Swaps node with its parent. The original parent becomes a child of the node.
# All other children of the original parent become children of the node. The
# node also keeps its original children.
#
# The lifted node gets the afun of the original parent while the original
# parent gets a new afun. The conll_deprel attribute is changed, too, to
# prevent possible coordination destruction.
#------------------------------------------------------------------------------
sub lift_node
{
    my $self = shift;
    my $node = shift;
    my $afun = shift; # new afun for the old parent
    my $parent = $node->parent();
    confess('Cannot lift a child of the root') if($parent->is_root());
    my $grandparent = $parent->parent();
    # Reattach myself to the grandparent.
    $node->set_parent($grandparent);
    $node->set_afun($parent->afun());
    $node->set_conll_deprel($parent->conll_deprel());
    # Reattach all previous siblings to myself.
    foreach my $sibling ($parent->children())
    {
        # No need to test whether $sibling==$node as we already reattached $node.
        $sibling->set_parent($node);
    }
    # Reattach the previous parent to myself.
    $parent->set_parent($node);
    $parent->set_afun($afun);
    $parent->set_conll_deprel('');
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
    my $i = $root->get_bundle()->get_position()+1;
    log_info("\#$i ".$root->get_zone()->sentence());
}



1;



=over

=item Treex::Block::A2A::CoNLL2PDTStyle

Common methods for language-dependent blocks that transform trees from the
various styles of the CoNLL treebanks to the style of the Prague Dependency
Treebank (PDT).

The analytical functions (afuns) need to be guessed from C<conll/deprel> and
other sources of information. The tree structure must be transformed at places
(e.g. there are various styles of capturing coordination).

Morphological tags should be decoded into Interset. Then the C<tag> attribute
should be set to the PDT 15-character positional tag matching the Interset
features.

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
