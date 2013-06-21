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
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone( $zone, 'conll2007' );
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
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
        my $deprel = $node->conll_deprel();
        my $afun   = $deprel;

        # PADT defines some afuns that were not defined in PDT.
        # PredE = existential predicate
        # PredC = conjunction as the clause's head
        # PredP = preposition as the clause's head
        if ( $afun =~ m/^Pred[ECP]$/ )
        {
            $afun = 'Pred';
        }

        # Ante = anteposition
        elsif ( $afun eq 'Ante' )
        {
            $afun = 'Apos';
        }

        # AuxE = emphasizing expression
        # AuxM = modifying expression
        elsif ( $afun =~ m/^Aux[EM]$/ )
        {
            $afun = 'AuxZ';
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
    # The '_M' suffix has been used in the CoNLL version of the Czech Prague Dependency Treebank to mark coordination membership.
    # Unfortunately it turns out that it was not used for Arabic.
    # Thus we have to estimate coordination membership (vs. shared modfiership) according to candidate afuns (once they have been set).
    foreach my $node (@nodes)
    {
        my $afun = $node->afun();
        if($afun =~ m/^(Coord|Apos)$/)
        {
            $self->identify_coap_members($node);
        }
    }
}

1;

=over

=item Treex::Block::A2A::AR::Harmonize

Converts PADT (Prague Arabic Dependency Treebank) trees from CoNLL to the style of
the Prague Dependency Treebank. The structure of the trees should already
adhere to the P(A)DT guidelines because the CoNLL trees come from PADT. Some
minor adjustments to the analytical functions may be needed while porting
them from the conll/deprel attribute to afun. Morphological tags will be
decoded into Interset and to the 15-character positional tags
of PDT. (Note that Arabic positional tagset in PADT differs from the Czech
tagset of PDT.)

=back

=cut

# Copyright 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
