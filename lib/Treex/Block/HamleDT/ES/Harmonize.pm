package Treex::Block::HamleDT::ES::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::HarmonizeAnCora';

# If there are any language-specific phenomena to handle, uncomment process_zone() and put the code there.
# Make sure to call $self->SUPER::process_zone($zone, 'conll2009') from there!
# sub process_zone {
#    my $root = $self->SUPER::process_zone($zone, 'conll2009');
#}



1;

=over

=item Treex::Block::HamleDT::ES::Harmonize

Converts Spanish trees from CoNLL 2009 to the HamleDT (Prague) style.
Relies on code that is common for both AnCora treebanks (Catalan and Spanish).

=back

=cut

# Copyright 2011-2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

=back

=cut

# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
