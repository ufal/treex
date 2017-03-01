package Treex::Block::HamleDT::Test::UD::CcIsLeaf;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    if($node->deprel() eq 'cc' && !$node->is_leaf())
    {
        $self->complain($node, 'Node attached as cc should be leaf.');
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::CcIsLeaf

The relation C<cc> is used for coordinating conjunctions, which are attached to the first conjunct and do not have their own dependents.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
