package Treex::Block::HamleDT::Test::UD::AuxChain;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $parent = $node->parent();
    if(defined($node->deprel()) && $node->deprel() =~ m/^aux(:|$)/ && defined($parent->deprel()) && $parent->deprel() =~ m/^aux(:|$)/)
    {
        $self->complain($node, 'Chains of two or more aux relations are forbidden.');
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::AuxChain

Auxiliary verbs should be attached except for coordination and multi-word
expressions serving as auxiliaries. More specifically, chains of nodes attached
using the C<aux> relation are forbidden.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
