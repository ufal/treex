package Treex::Block::HamleDT::GRC::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizePerseus';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'grc::conll',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);

#------------------------------------------------------------------------------
# Reads the Ancient Greek CoNLL trees, converts morphosyntactic tags to the positional
# tagset and transforms the tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone);
    $self->fix_negation($root);
    $self->check_afuns($root);
}

#------------------------------------------------------------------------------
# Tries to separate negation from all the AuxZ modifiers.
#------------------------------------------------------------------------------
sub fix_negation
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->afun() eq 'AuxZ')
        {
            # I believe that the following function as negative particles in Ancient Greek (based on Google search).
            # I suspect that there are other forms that I am missing here.
            if($node->form() =~ m/^(οὐ|οὔ|οὐκ|μὴ|μη|μή|οὐχ)$/i)
            {
                $node->set_afun('Neg');
            }
        }
    }
}

#------------------------------------------------------------------------------
# Fixes a few known annotation errors that appear in the data. Should be called
# from deprel_to_afun() so that it precedes any tree operations that the
# superordinate class may want to do.
#------------------------------------------------------------------------------
sub fix_annotation_errors
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({ordered => 1});
    foreach my $node (@nodes)
    {
        my $parent = $node->parent();
        my @children = $node->children();
        # Coord is leaf or its children are not conjuncts.
        if($node->afun() eq 'Coord' && scalar(grep {$_->is_member()} (@children))==0)
        {
            # Deficient sentential coordination: conjunctless Coord is child of root.
            if($parent->is_root())
            {
                my @conjuncts = grep {$_ != $node && $_->afun() =~ m/^(Pred|ExD|Coord|Apos|AuxP|AuxC|Adv)$/} ($parent->children());
                if(@conjuncts)
                {
                    # Loop over all children, not just conjuncts. If there are delimiters, they must be attached as well.
                    foreach my $child ($parent->children())
                    {
                        next if($child==$node);
                        # If this function is called from deprel_to_afun(), attachment of sentence-final punctuation will be assessed later.
                        # Thus we do not need to check whether the node we are modifying is or is not AuxK.
                        $child->set_parent($node);
                        if($child->afun() !~ m/^(Coord|Apos)$/ && $child->form() eq ',')
                        {
                            $child->set_afun('AuxX');
                        }
                        else
                        {
                            if($child->afun() eq 'Adv')
                            {
                                $child->set_afun('ExD');
                            }
                            $child->set_is_member(1);
                        }
                    }
                }
            }
            elsif($node->is_leaf())
            {
                # Comma + coordinating conjunctin/particle. Coordination headed by the
                # comma, the conjunction attached as leaf several levels down, but it
                # is labeled Coord.
                # Is it a conjunction or a particle?
                if($node->get_iset('pos') =~ m/^(conj|part)$/)
                {
                    # Is the preceding token comma, labeled as Coord?
                    my $previous = $node->get_prev_node();
                    if($previous && $previous->form() eq ',' && $previous->afun() eq 'Coord')
                    {
                        my $conjunction = $node;
                        my $comma = $previous;
                        # Attach the conjunction where the comma was attached.
                        my $parent = $comma->parent();
                        $conjunction->set_parent($parent);
                        if($comma->is_member())
                        {
                            $conjunction->set_is_member(1);
                        }
                        # Attach all children of the comma (conjuncts, shared modifiers and delimiters) to the conjunction.
                        # They will keep their current afuns and is_member values.
                        foreach my $child ($comma->children())
                        {
                            $child->set_parent($conjunction);
                        }
                        # Attach the comma to the conjunction.
                        $comma->set_parent($conjunction);
                        $comma->set_afun('AuxX');
                        $comma->set_is_member(undef);
                    }
                    else # this is conj or part, preceding node is not coordinating comma
                    {
                        # Two subjects followed by the particle "te", all attached as siblings.
                        my @preceding_tokens = grep {$_->ord() < $node->ord()} (@nodes);
                        if(scalar(@preceding_tokens)>=2 &&
                        $preceding_tokens[$#preceding_tokens]->parent()==$parent &&
                        $preceding_tokens[$#preceding_tokens-1]->parent()==$parent &&
                        $preceding_tokens[$#preceding_tokens]->afun() eq $preceding_tokens[$#preceding_tokens-1]->afun())
                        {
                            $preceding_tokens[$#preceding_tokens]->set_parent($node);
                            $preceding_tokens[$#preceding_tokens]->set_is_member(1);
                            $preceding_tokens[$#preceding_tokens-1]->set_parent($node);
                            $preceding_tokens[$#preceding_tokens-1]->set_is_member(1);
                        }
                        # A strange combination of prepositional phrases and coordinating elements: o d' es te Pytho kapi Dodonis pyknous theopropous iallen
                        elsif($node->get_right_neighbor()->afun() eq 'Coord')
                        {
                            $node->set_parent($node->get_right_neighbor());
                            $node->set_afun('AuxY');
                        }
                        # Deficient sentential coordination.
                        elsif($parent eq 'Pred')
                        {
                            my $grandparent = $parent->parent();
                            $node->set_parent($grandparent);
                            $parent->set_parent($node);
                            $parent->set_is_member(1);
                        }
                        else
                        {
                            $node->set_afun('AuxY');
                        }
                    }
                }
                # Shared modifier of upper-level coordination.
                elsif($node->get_iset('pos') eq 'adj' && $node->parent()->afun() eq 'Coord')
                {
                    my @eparents = grep {$_->is_member()} ($node->parent()->children());
                    if(@eparents && $eparents[0]->get_iset('pos') eq 'noun')
                    {
                        $node->set_afun('Atr');
                    }
                }
            } # if Coord is_leaf
            # Coord is not leaf but there are no conjuncts among its children.
            else
            {
                if(scalar(@children)==1 && $children[0]->afun() eq 'AuxY' && $parent->afun() eq 'Coord')
                {
                    # Both this node and its child are secondary conjunctions of a larger coordination.
                    $node->set_afun('AuxY');
                    $children[0]->set_parent($parent);
                }
            }
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::GRC::Harmonize

Converts Ancient Greek dependency treebank to the HamleDT (Prague) style.
Most of the deprel tags follow PDT conventions but they are very elaborated
so we have shortened them.

=back

=cut

# Copyright 2011, 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# Copyright 2011 Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
