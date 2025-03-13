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
    # Fix a rare combination of preposition and subordinated clause in copula predication.
    $self->fix_be_for_that($root);
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
# This function targets a rare construction observed in Czech (and specifically
# in PDT-C 2.0) but the function is language-independent and could act on other
# languages, too. The Czech example is "byl by pro, abychom dělali X" = "he
# would be for (it) that we do X". Here "byl by" is a conditional copula and
# the rest (including the nested clause) is a predicate. Nevertheless, the afun
# Pnom for nominal predicates is not present; instead, the preposition "pro"
# has AuxP, its child "abychom" has AuxC, and the verb under "abychom" has Adv
# because it is an adverbial clause. We will replace the AuxP of "pro" with
# Pnom. It will address two issues that would otherwise occur when moving to
# UD: The nominal predicate with copula would not be recognized, and the
# preposition would be treated as another marker (besides "abychom") of the
# subordinate clause.
#------------------------------------------------------------------------------
sub fix_be_for_that
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        # Do not ask whether the lemma of the parent is "být".
        # Keep the function language-independent and hope that this pattern
        # never occurs with verbs that are not copulas.
        if($node->deprel() eq 'AuxP' && $node->parent()->is_verb())
        {
            my @children = $node->children();
            if(scalar(@children) == 1 && $children[0]->deprel() eq 'AuxC')
            {
                $node->set_deprel('Pnom');
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
