package Treex::Block::HamleDT::Test::UD::CompoundPrepositions;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $iset  = $node->iset();
    my $deprel = $node->conll_deprel();
    $deprel = '' if(!defined($deprel));
    # Czech "na rozdíl od" is a compound preposition. The first token should be head, the second and the third token should depend on it as mwe.
    ###!!! IMPLEMENTATION NOT FINISHED! If we encounter a sequence of tokens known to be compound preposition, we must check how it is analyzed.
    if ($node->form() =~ m/^(širokorozchodnou|investovaly)$/i)
    {
        $self->complain($node, $node->form());
    }
    else
    {
        $self->praise($node);
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::CompoundPrepositions

=back

=cut

# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

