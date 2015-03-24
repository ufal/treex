package Treex::Block::HamleDT::Test::UD::Punctuation;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    # There are "sentences" that consist entirely of punctuation.
    # In that case they are allowed to depend directly on the root and the label will be 'root', not 'punct'.
    my @punctnodes = grep {$_->is_punctuation()} (@nodes);
    unless(scalar(@punctnodes) == scalar(@nodes))
    {
        foreach my $node (@nodes)
        {
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
                # Exception: '(!)' ... the brackets depend on the exclamation mark.
                # (But we do not allow just one bracket. Then it should be attached elsewhere.)
                my @children = $node->get_children({'ordered' => 1});
                unless(scalar(@children)==2 && $children[0]->form() eq '(' && $children[1]->form() eq ')')
                {
                    $self->complain($node, $node->form().' should be leaf');
                }
            }
        }
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
