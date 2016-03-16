package Treex::Block::HamleDT::Test::UD::CcIsConjunction;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    if($node->deprel() eq 'cc' && !$node->is_conjunction())
    {
        $self->complain($node, $node->form());
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::CcIsConjunction

The relation C<cc> is used for coordinating conjunctions.
It can occasionally appear with a word tagged as adverb or something else, but it is not expected to be noun, verb or adjective.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
