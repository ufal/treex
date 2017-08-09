package Treex::Block::HamleDT::Test::UD::CcDependsOnFollowingConjunct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    # A coordinating conjunction can appear outside of coordination.
    # We will only check cases that seem to be coordination.
    if($node->deprel() eq 'cc')
    {
        # Are there right siblings attached as 'conj'?
        my @conjsiblings = grep {$_->deprel() eq 'conj' && $_->ord() > $node->ord()} ($node->get_siblings({'ordered' => 1}));
        if(scalar(@conjsiblings) > 0)
        {
            # Since the conjuncts are attached as my siblings, I am not attached to one of them, which would be the UD v2 style.
            # Instead, I am probably attached to the first sibling, which is the UD v1 style and which is now wrong.
            # Exception: If there is nested coordination, I may be attached correctly to the next conjunct
            # and still have conjuncts as siblings.
            # Another exception: I may occur before the first conjunct and be correctly attached to it (but it does not have the 'conj' deprel),
            # as in "ni Beograd ni Priština".
            unless($node->parent()->ord() > $node->ord() && $node->parent()->ord() < $conjsiblings[0]->ord())
            {
                $self->complain($node, 'Old style of cc attachment.');
            }
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::CcDependsOnFollowingConjunct

The relation C<cc> is used for coordinating conjunctions, which are attached to the following conjunct (unless they occur after the last conjunct).

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
