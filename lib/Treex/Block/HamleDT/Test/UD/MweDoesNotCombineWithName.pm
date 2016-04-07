package Treex::Block::HamleDT::Test::UD::MweDoesNotCombineWithName;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my @children = $node->children();
    my @mwe = grep {$_->deprel() eq 'mwe'} (@children);
    my @name = grep {$_->deprel() eq 'name'} (@children);
    if(scalar(@mwe) > 0 && scalar(@name) > 0)
    {
        $self->complain($node, 'The node has both mwe and name children.');
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::MweDoesNotCombineWithName

The relations C<mwe> and C<name> are both used in flat structures of two or
more nodes belonging to the same multi-word expression or name. The first word
is the head and the other words are attached to it using the C<mwe> or C<name>
relation.

The head may have other children, too. If there are other children, they are
understood as modifying the entire multi-word expression. However, one node
cannot have a mix of C<mwe> and C<name> children. It cannot participate in two
different multi-word expressions at the same time. Moreover, C<name> is used
with proper nouns, C<mwe> is used with function words, and one word cannot be
both.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
