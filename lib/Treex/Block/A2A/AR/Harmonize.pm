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
