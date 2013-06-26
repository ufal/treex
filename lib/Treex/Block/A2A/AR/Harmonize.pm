package Treex::Block::A2A::AR::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::Harmonize';

#------------------------------------------------------------------------------
# Reads the Arabic tree, converts morphosyntactic tags to the PDT tagset,
# converts deprel tags to afuns, transforms tree to adhere to PDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $self->SUPER::process_zone($zone, 'padt');
    $self->attach_final_punctuation_to_root($root);
    $self->fill_in_lemmas($root);
    $self->fix_coap_ismember($root);
    $self->fix_auxp($root);
}

#------------------------------------------------------------------------------
# Adjusts analytical functions (syntactic tags). This method is called
# deprel_to_afun() due to compatibility reasons. Nevertheless, it does not use
# the value of the conll/deprel attribute. We converted the PADT PML files
# directly to Treex without CoNLL, so the afun attribute already has a value.
# We filled conll/deprel as well but the values are not identical to afun: they
# also reflect other attributes such as is_member.
# less /net/data/conll/2007/ar/doc/README
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $afun   = $node->afun();

        # PADT defines some afuns that were not defined in PDT.
        # PredE = existential predicate
        # PredC = conjunction as the clause's head
        # PredP = preposition as the clause's head
        if ( $afun =~ m/^Pred[ECP]$/ )
        {
            #$afun = 'Pred';
        }

        # Ante = anteposition
        elsif ( $afun eq 'Ante' )
        {
            #$afun = 'Apos';
        }

        # AuxE = emphasizing expression
        # AuxM = modifying expression
        elsif ( $afun =~ m/^Aux[EM]$/ )
        {
            #$afun = 'AuxZ';
        }

        # _ = excessive token esp. due to a typo
        elsif ( $afun eq '_' )
        {
            $afun = '';
        }

        # Beware: PADT allows joint afuns such as 'ExD|Sb', which are not allowed by the PML schema.
        $afun =~ s/\|.*//;
        $node->set_afun($afun || 'NR');
    }
}

#------------------------------------------------------------------------------
# Repairs annotation of coordinations and appositions. The current PADT data
# contain nodes that are marked as members of either coordination or apposition
# but their parent's afun is neither Coord nor Apos. It also contains nodes
# with one of these afuns that do not have any children marked as members.
#------------------------------------------------------------------------------
sub fix_coap_ismember
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        # Orphan conjuncts.
        if($node->is_member())
        {
            my $parent = $node->parent();
            if($parent->afun() !~ m/^(Coord|Apos)$/)
            {
                # Make the parent Coord root if it is a coordinating conjunction or a comma.
                if($parent->get_iset('pos') eq 'conj' || $parent->form() eq '،')
                {
                    $parent->set_afun('Coord');
                }
                # Otherwise remove the membership flag.
                else
                {
                    $node->set_is_member(0);
                }
            }
        }
        # Empty coordinations.
        if($node->afun() =~ m/^(Coord|Apos)$/ && !grep {$_->is_member()} ($node->children()))
        {
            my $afun = $node->afun();
            my @children = $node->children();
            # Misannotated deficient coordination (a single conjunct).
            if($afun eq 'Coord' && scalar(@children)==1)
            {
                $children[0]->set_is_member(1);
            }
            # Misannotated normal coordination.
            # Most such Coord nodes are conjunctions ($node->get_iset('pos') eq 'conj')
            # but some of them are punctuations and quite a few are unrecognized words
            # that should have been split into multiple tokens, the first token being the
            # conjunction و wa (and).
            elsif($afun eq 'Coord' && scalar(@children)>1)
            {
                # Exclude AuxG children, e.g. quotation marks around the coordination, or commas between conjuncts.
                # Exclude AuxY children, i.e. additional conjunctions.
                my $found = 0;
                foreach my $child (@children)
                {
                    unless($child->afun() =~ m/^(AuxG|AuxY)$/)
                    {
                        $child->set_is_member(1);
                        $found = 1;
                    }
                }
                # What to do if there were only ineligible children?
                unless($found)
                {
                    ###!!!
                }
            }
            # Misannotated apposition.
            elsif($afun eq 'Apos' && scalar(@children)==2)
            {
                $children[0]->set_is_member(1);
                $children[1]->set_is_member(1);
            }
            # Apposition with one child? I do not understand the examples but I assume that these are actually members of appositions that lack the joining node.
            # ###!!! This may be quite wrong! Get translations of the examples!
            elsif($afun eq 'Apos' && scalar(@children)==1)
            {
                $node->set_afun('Apposition');
            }
            # Other errors: coordination/apposition root has no children at all.
            elsif(scalar(@children)==0)
            {
                # We cannot say how this error arose.
                # Resort to default tags: ExD under the root, Adv under a verb, Atr elsewhere.
                $self->set_default_afun($node);
            }
            ###!!! Další případy: uzel se spojkou wa má Apos (ne Coord!), má tři děti - předměty slovesa, které je jeho rodičem.
        }
    }
}

#------------------------------------------------------------------------------
# Reconsiders syntactic tags of prepositions. Most of them should have AuxP and
# those that don't should have a good reason.
#------------------------------------------------------------------------------
sub fix_auxp
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        if($node->get_iset('pos') eq 'prep' && scalar($node->children())>=1)
        {
            # There is no reason for prepositions to receive AuxY.
            # AuxY is meant for "other adverbs and particles, i.e. those that cannot be included elsewhere".
            if($node->afun() eq 'AuxY')
            {
                $node->set_afun('AuxP');
            }
        }
    }
}

1;

=over

=item Treex::Block::A2A::AR::Harmonize

Converts PADT (Prague Arabic Dependency Treebank) trees to the style of HamleDT.
The structure of the trees should already adhere to the guidelines because the
the annotation scheme of PADT is very similar to PDT. Some
minor adjustments to the analytical functions may be needed.
Morphological tags will be decoded into Interset and to the 15-character positional tags
of PDT. (Note that Arabic positional tagset in PADT differs from the Czech
tagset of PDT.)

=back

=cut

# Copyright 2011, 2013 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
