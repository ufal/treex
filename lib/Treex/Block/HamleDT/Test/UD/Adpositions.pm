package Treex::Block::HamleDT::Test::UD::Adpositions;
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
        # In some languages the borderline between adpositions and subordinating conjunctions is fuzzy.
        # If a preposition is attached to a verb, it is treated as a subordinating conjunction and the relation is labeled 'mark'
        # (example [en]: "after kidnapping him"; note that English gerunds are tagged VERB, not NOUN).
        # Some prepositions in Germanic languages may function as verbal particles (or separable verb prefixes). They are tagged ADP but their relation to the verb is labeled 'compound:prt'.
        # Examples:
        # [en]: up, out, off, down, on
        # [da]: op, siden, ud, af, sammen
        # [sv]: ut, till, upp, in, med
        if($node->is_adposition())
        {
            my $ok = $node->is_leaf();
            if(!$ok)
            {
                $ok = !any {$_->deprel() !~ m/^(mwe|conj|cc)$/} ($node->children());
            }
            my $parent = $node->parent();
            my $deprel = $node->deprel();
            if($parent->is_root())
            {
                $ok = $ok && $deprel eq 'root';
            }
            else
            {
                my $dir = $node->ord() - $parent->ord();
                if($deprel =~ m/^(mwe|conj)$/)
                {
                    $ok = $ok && $dir > 0; # parent is to the left from the adposition
                }
                elsif($parent->is_verb())
                {
                    $ok = $ok && $deprel =~ m/^(mark|compound:prt)$/;
                }
                else
                {
                    $ok = $ok && $deprel eq 'case';
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

=item Treex::Block::HamleDT::Test::UD::Adpositions

A preposition normally depends on a following node (usually noun) and the relation is 'case'.
It may also depend on a preceding node as 'mwe' or 'conj'.
In case of ellipsis (incomplete sentence), it may depend on the root as 'root'.
In any case, the preposition should be leaf.

=back

=cut

# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
