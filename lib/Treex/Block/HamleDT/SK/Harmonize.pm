package Treex::Block::A2A::SK::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::Harmonize';

#------------------------------------------------------------------------------
# Reads the Slovak tree, converts morphosyntactic tags to the PDT tagset,
# converts afuns if applicable, transforms tree to adhere to HamleDT guidelines.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $a_root = $self->SUPER::process_zone($zone, 'snk');
}

#------------------------------------------------------------------------------
# Convert dependency relation tags to analytical functions.
# http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/cz/a-layer/html/ch03s02.html
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self  = shift;
    my $root  = shift;
    my @nodes = $root->get_descendants();
    # Nothing to change at the moment. They use the Prague set of analytical functions.
}

1;

=over

=item Treex::Block::A2A::SK::Harmonize

Converts SNK (Slovak National Corpus) trees to the HamleDT style. Currently
it only involves conversion of the morphological tags (and Interset decoding).

=back

=cut

# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
