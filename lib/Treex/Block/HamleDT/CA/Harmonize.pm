package Treex::Block::HamleDT::CA::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizeAnCora';

has iset_driver =>
(
    is            => 'ro',
    isa           => 'Str',
    required      => 1,
    default       => 'ca::conll2009',
    documentation => 'Which interset driver should be used to decode tags in this treebank? '.
                     'Lowercase, language code :: treebank code, e.g. "cs::pdt".'
);

# If there are any language-specific phenomena to handle, uncomment process_zone() and put the code there.
# Make sure to call $self->SUPER::process_zone($zone) from there!
# sub process_zone {
#    my $root = $self->SUPER::process_zone($zone);
#}



1;

=over

=item Treex::Block::HamleDT::CA::Harmonize

Converts Catalan trees from CoNLL 2009 to the HamleDT (Prague) style.
Relies on code that is common for both AnCora treebanks (Catalan and Spanish).

=back

=cut

# Copyright 2011-2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
