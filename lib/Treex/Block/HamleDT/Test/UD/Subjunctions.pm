package Treex::Block::HamleDT::Test::UD::Subjunctions;
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
        # A subordinating conjunction normally depends on a following node (usually verb) and the relation is 'mark'.
        # It may also depend on a preceding node as 'conj'.
        # In case of ellipsis (incomplete sentence), it may depend on the root as 'root'.
        # There are also multiword subordinators: [cs] "i když" (even though/if), "jako když" (as if).
        if($node->is_subordinator())
        {
            my $parent = $node->parent();
            my $deprel = $node->deprel();
            # Do not test subordinators in foreign text, they have their own rules for attachment.
            next if($deprel eq 'foreign');
            # In some cases the subordinating conjunction can have children.
            my @forbidden_children = grep {$node->deprel() !~ m/^(mwe)$/} ($node->children());
            my $ok = scalar(@forbidden_children)==0 || $parent->is_root();
            if($parent->is_root())
            {
                $ok = $ok && $deprel eq 'root';
            }
            else
            {
                my $dir = $node->ord() - $parent->ord();
                my $form = $node->form();
                if($deprel =~ m/^(conj|mwe)$/)
                {
                    $ok = $ok && $dir > 0; # parent is to the left from the subordinating conjunction
                }
                # Some Czech words are tagged as subordinating conjunctions although in fact they function
                # as relative adverbs.
                elsif($deprel eq 'advmod')
                {
                    $ok = $ok && lc($form) =~ m/^(jak|přičemž|dokud|zato)$/;
                }
                # AuxO = discourse: ", komu že odkáže svou říši"
                elsif($deprel eq 'discourse')
                {
                    $ok = $ok && lc($form) eq 'že';
                }
                else
                {
                    # It is not so rare that certain conjunctions are judged by dictionary as subordinating
                    # but they are actually used as coordinating. So we must allow 'cc', too.
                    $ok = $ok && $deprel =~ m/^(mark|cc)$/;
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

=item Treex::Block::HamleDT::Test::UD::Subjunctions

A subordinating conjunction normally depends on a following node (usually verb) and the relation is 'mark'.
It may also depend on a preceding node as 'conj'.
In case of ellipsis (incomplete sentence), it may depend on the root as 'root'.
In any case, the subjunction should be leaf.

=back

=cut

# Copyright 2015 Dan Zeman
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
