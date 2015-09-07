package Treex::Block::HamleDT::MT::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'mt::mlss',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt". '.
                     'The driver must be available in "$TMT_ROOT/libs/other/tagset".'
);

my $debug = 0;



#------------------------------------------------------------------------------
# The Maltese corpus actually does not contain trees, everything is attached
# directly to the root. But we have to convert POS tags.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self   = shift;
    my $zone   = shift;
    my $root = $self->SUPER::process_zone($zone);
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
    return $node->conll_pos();
}



#------------------------------------------------------------------------------
# This method is necessary for the harmonization block to work but there is not
# much we could do in the case of Maltese, as there are no real dependencies.
#------------------------------------------------------------------------------
sub deprel_to_afun
{
    my $self   = shift;
    my $root   = shift;
    my @nodes  = $root->get_descendants();
    for my $node (@nodes)
    {
        my $afun = 'ExD';
        $node->set_afun($afun);
    }
}



1;

=over

=item Treex::Block::HamleDT::MT::Harmonize

Converts Maltese part-of-speech tags to Interset.
There are no tree transformations in the case of Maltese because the input does not contain
trees.

=back

=cut

# Copyright 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
