package Treex::Block::HamleDT::Test::UD::ConjLeftToRight;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $deprel = $node->deprel();
    if($deprel eq 'conj')
    {
        my $parent = $node->parent();
        if(!defined($parent) || $parent->ord() >= $node->ord())
        {
            $self->complain($node, 'conj must always go from left to right');
        }
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::ConjLeftToRight

The relation C<conj> must always be left-to-right (head-initial).

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
