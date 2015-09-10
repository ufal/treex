package Treex::Block::Test::Phrase;
use Moose;
use Treex::Core::Common;
use Treex::Core::Phrase::Builder;
use utf8;
extends 'Treex::Block::Test::BaseTester';



#------------------------------------------------------------------------------
# Converts a dependency tree to phrase-structure tree and back. We should get
# the same structure.
#------------------------------------------------------------------------------
sub process_atree
{
    my $self = shift;
    my $root = shift;
    my $builder = new Treex::Core::Phrase::Builder;
    my $phrase = $builder->build($root);
    $phrase->project_dependencies();
    ###!!! And now we should check that the projected dependency tree does not
    ###!!! differ from the original.
}



1;

=over

=item Treex::Block::Test::Phrase

Converts a dependency (a-) tree to phrase-structure tree and back.
We should get the same structure.

=back

=cut

# Copyright 2015 Dan Zeman <zeman@ufal.mff.cuni.cz>
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
