package Treex::Block::HamleDT::HarmonizePDT;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseBuilder::Prague;
extends 'Treex::Block::HamleDT::Harmonize';

#------------------------------------------------------------------------------
# Reads the Prague style trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $tagset = shift;
    my $root = $self->SUPER::process_zone($zone, $tagset);
    my @nodes = $root->get_descendants({ordered => 1});
    # An easy bug to fix in deprels. It is rare but it exists.
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'AuxX' && $node->form() ne ',' && $node->is_punctuation())
        {
            $node->set_deprel('AuxG');
        }
        # The letter 'x' used instead of the operator of multiplication ('×').
        if($node->deprel() eq 'AuxG' && $node->form() eq 'x' && $node->is_conjunction())
        {
            $node->set_deprel('AuxY');
        }
        # AuxK used for question marks and exclamation marks that terminate phrases but not the whole sentence.
        if($node->deprel() eq 'AuxK' && !$node->parent()->is_root())
        {
            $node->set_deprel($node->form() eq ',' ? 'AuxX' : 'AuxG');
        }
    }
    $self->fix_list_item_labels($root); # CLTT issue, but it could occur elsewhere, too.
    # Is_member should be set directly under the Coord|Apos node. Some Prague-style treebanks have it deeper.
    # Fix it here, before building phrases (it will not harm treebanks that are already OK.)
    $self->pdt_to_treex_is_member_conversion($root);
    # Phrase-based implementation of tree transformations (30.11.2015).
    my $builder = new Treex::Tool::PhraseBuilder::Prague
    (
        'prep_is_head'           => 1,
        'coordination_head_rule' => 'last_coordinator'
    );
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    # Apposition "zvratné, tj. jako vracející se zpět k podmětu": The conjunction
    # was "tj.", it is now attached to "jako", which is an AuxC and its only child
    # should be "vracející". Move the conjunction further down to "vracející" so
    # that it is not later considered as a fixed expression "tj. jako". ###!!!
    # It would be better to do this within the phrase builder: First encapsulate
    # "tj." including the period in one nonterminal (so that the period stays attached
    # to it), then make sure that prepositional phrases attach further dependents
    # to the argument and not to the preposition (here conjunction "jako").
    foreach my $node (@nodes)
    {
        if($node->form() eq 'tj')
        {
            my $period = $node->get_next_node();
            if($period->form() eq '.')
            {
                my $jako = $period->get_next_node();
                if($jako->form() eq 'jako' && $node->parent() == $jako && $period->parent() == $jako)
                {
                    my @children = grep {$_ != $node && $_ != $period} ($jako->get_children({'ordered' => 1}));
                    if(scalar(@children) > 0)
                    {
                        $node->set_parent($children[0]);
                        $period->set_parent($node);
                    }
                }
            }
        }
    }
    # We used to reattach final punctuation before handling coordination and apposition but that was a mistake.
    # The sentence-final punctuation might serve as coap head, in which case this function must not modify it.
    # The function knows it but it cannot be called before coap annotation has stabilized.
    $self->attach_final_punctuation_to_root($root);
    # is_member undef and is_member 0 are equivalent; however, the latter makes larger XML file.
    foreach my $node (@nodes)
    {
        $node->set_is_member(undef) if(!$node->is_member());
    }
    return $root;
}



#------------------------------------------------------------------------------
# Fix list item labels attached to AuxP or AuxC. For example, in Czech CLTT,
# "d) pokud tak stanoví zvláštní právní předpis"
# "d) if so provided by a special legal regulation"
# "d)" is one token, tagged "X@", attached as "AuxG" directly to "pokud", which
# is AuxC_Co and has "stanoví" as the second child. This is not a problem when
# "d)" is treated as punctuation, but it is not punctuation, and "AuxG" will be
# converted to generic "nmod" in convert_deprels(). Therefore, we should detect
# and fix such cases before deprels are converted.
#------------------------------------------------------------------------------
sub fix_list_item_labels
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->deprel() eq 'AuxG' && $node->form() =~ m/^[A-Za-z0-9]+[\)\.]$/)
        {
            $node->set_deprel('Adv');
            if($node->parent()->deprel() =~ m/^Aux[CP]/)
            {
                my @siblings = $node->get_siblings({'ordered' => 1, 'add_self' => 0});
                if(scalar(@siblings) > 0)
                {
                    $node->set_parent($siblings[0]);
                }
            }
        }
    }
}



#------------------------------------------------------------------------------
# Coordination of prepositional phrases or subordinate clauses:
# In PDT, is_member is set at the node that bears the real deprel. It is not
# set at the AuxP/AuxC node. In HamleDT (and in Treex in general), is_member is
# set directly at the child of the coordination head (preposition or not). This
# function moves the is_member attribute wherever needed to match the HamleDT
# convention. The function is adapted from Zdeněk's block HamleDT::
# Pdt2TreexIsMemberConversion (now removed).
#
# Note that HarmonizePerseus does this conversion during conversion of deprels.
# It does not call pdt_to_treex_is_member_conversion() but it does make use of
# the _climb_up_below_coap() function defined below. When we arrive here from
# HarmonizePerseus, is_member has been converted. But we will have work if we
# arrive directly from this block or from another derivate.
#------------------------------------------------------------------------------
sub pdt_to_treex_is_member_conversion
{
    my $self = shift;
    my $root = shift;
    foreach my $old_member (grep {$_->is_member()} ($root->get_descendants()))
    {
        my $new_member = $self->_climb_up_below_coap($old_member);
        if ($new_member && $new_member != $old_member)
        {
            $new_member->set_is_member(1);
            $old_member->set_is_member(undef);
        }
    }
}



#------------------------------------------------------------------------------
# Searches for the next Coord/Apos node on the path from a node to the root.
# Returns the node directly under the Coord/Apos node. If no Coord/Apos node is
# found, the result is undefined.
#------------------------------------------------------------------------------
sub _climb_up_below_coap
{
    my $self = shift;
    my ($node) = @_;
    my $debug_address = $node->get_address();
    my @debug_path = ($node->form());
    while(1)
    {
        my $parent = $node->parent();
        my $pdeprel = $parent->deprel() // '';
        if ($parent->is_root())
        {
            push(@debug_path, 'ROOT');
            log_warn('No Coord/Apos node between a member of coordination/apposition and the tree root');
            log_warn($debug_address);
            log_warn('The path: '.join(' ', @debug_path));
            return;
        }
        # We cannot use $parent->is_coap_root() because it queries the afun attribute while we use the deprel attribute.
        elsif ($parent->deprel() =~ m/^(Coord|Apos)/i)
        {
            return $node;
        }
        else
        {
            push(@debug_path, $parent->form());
            $node = $parent;
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::HarmonizePDT

Common methods needed for conversion of treebanks from the Prague family to HamleDT.
Since the HamleDT annotation style is for most part identical to the style of PDT,
this block merely handles slight deviations of the other Prague and Prague-like treebanks.
It also provides methods for fixing some errors, such as missing conjuncts in coordination.

=back

=cut

# Copyright 2014, 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2011 Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
