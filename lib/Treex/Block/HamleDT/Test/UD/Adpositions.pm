package Treex::Block::HamleDT::Test::UD::Prepositions;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        # A preposition normally depends on a following node (usually noun) and the relation is 'case'.
        # It may also depend on a preceding node as 'mwe' or 'conj'.
        # In case of ellipsis (incomplete sentence), it may depend on the root as 'root'.
        if($node->is_adposition())
        {
            my $ok = $node->is_leaf();
            my $parent = $node->parent();
            my $deprel = $node->deprel();
            if($parent->is_root())
            {
                $ok = $deprel eq 'root';
            }
            else
            {
                my $dir = $node->ord() - $parent->ord();
                if($deprel =~ m/^(mwe|conj)$/)
                {
                    $ok = $dir < 0; # parent is to the left from the adposition
                }
                else
                {
                    $ok = $deprel eq 'case';
                }
            }
            if(!$ok)
            {
                $self->complain($node, $node->form().' '.$deprel);
            }
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::Prepositions

A preposition normally depends on a following node (usually noun) and the relation is 'case'.
It may also depend on a preceding node as 'mwe' or 'conj'.
In case of ellipsis (incomplete sentence), it may depend on the root as 'root'.
In any case, the preposition should be leaf.

=back

=cut

# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
