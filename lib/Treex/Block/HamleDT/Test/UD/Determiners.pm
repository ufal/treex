package Treex::Block::HamleDT::Test::UD::Determiners;
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
    if ($iset->upos() eq 'DET' && $deprel !~ m/^det(:numgov|:nummod)?$/)
    {
        $self->complain($node, $node->form().' '.$iset->upos().' '.$deprel);
    }
    elsif ($deprel =~ m/^det(:numgov|:nummod)?$/ && $iset->upos() ne 'DET')
    {
        $self->complain($node, $node->form().' '.$iset->upos().' '.$deprel);
    }
    else
    {
        $self->praise($node);
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::Determiners

Determiners should have the universal POS tag C<DET> and the dependency relation C<det>.
That is, any of these two labels implies the other one.
It is a good idea to check that it holds. In quite a few languages determiners
are distinguished from pronouns using heuristics. This test shows how good the
heuristics are.

=back

=cut

# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.

