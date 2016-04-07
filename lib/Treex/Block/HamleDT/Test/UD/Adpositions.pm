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
            my $parent = $node->parent();
            my $deprel = $node->deprel();
            # Do not test adpositions in foreign text, they have their own rules for attachment.
            next if($deprel eq 'foreign');
            # Do not test adpositions that are part of a multi-word expression. MWE's must be tested separately by their own rules.
            # The whole MWE may act as something else than adposition. It can be an advmod.
            next if($deprel eq 'mwe' || any {$_->deprel() eq 'mwe'} ($node->children()));
            my $ok = $node->is_leaf();
            if(!$ok)
            {
                $ok = !any {$_->deprel() !~ m/^(conj|cc)$/} ($node->children());
            }
            if($parent->is_root())
            {
                $ok = $ok && $deprel eq 'root';
            }
            else
            {
                my $dir = $node->ord() - $parent->ord();
                if($deprel =~ m/^(conj)$/)
                {
                    $ok = $ok && $dir > 0; # parent is to the left from the adposition
                }
                # The 'mark' relation is used instead of 'case' if the adposition modifies an entire clause (that is, the adposition functions as a subordinating conjunction).
                # That usually means that the parent is a non-finite verb form such as infinitive or gerund. However, if the verb is copula, it will be sibling, not parent.
                # Note however, that nominal predicates with a copula may also have genuine adposition ('case') modifiers.
                # 'case' example: Couceiro dijo que España está en el buen camino ... ccomp(dijo, camino); cop(camino, está); case(camino, en)
                # 'mark' example: hace hincapié en que los retornos son muy elevados ... ccomp(hace, elevados); mark(elevados, en); cop(elevados, son)
                elsif($parent->is_verb())
                {
                    $ok = $ok && $deprel =~ m/^(mark|compound:prt)$/;
                }
                elsif(any {defined($_->deprel()) && $_->deprel() eq 'cop'} ($parent->children()))
                {
                    $ok = $ok && $deprel =~ m/^(mark|case)$/;
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
