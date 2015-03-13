package Treex::Block::HamleDT::Test::UD::Punctuation;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $iset  = $node->iset();
    my $deprel = $node->deprel();
    $deprel = '' if(!defined($deprel));
    if ($iset->upos() eq 'PUNCT' && $deprel ne 'punct')
    {
        $self->complain($node, $node->form().' '.$iset->upos().' '.$deprel);
    }
    elsif ($deprel eq 'punct' && $iset->upos() ne 'PUNCT')
    {
        $self->complain($node, $node->form().' '.$iset->upos().' '.$deprel);
    }
    elsif ($deprel eq 'punct' && !$node->is_leaf())
    {
        $self->complain($node, $node->form().' should be leaf');
    }
    else
    {
        $self->praise($node);
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::Punctuation

Punctuation nodes should have the universal POS tag C<PUNCT> and the dependency relation C<punct>.
That is, any of these two labels implies the other one.
The punctuation nodes should be leaves.

=back

=cut

# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
