package Treex::Block::HamleDT::Test::UD::AdverbIsNotNmod;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    if($node->is_adverb() && defined($node->deprel()) && $node->deprel() eq 'nmod')
    {
        $self->complain($node);
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::AdverbIsNotNmod

Adverbial modifiers realized as adverbs are 'advmod'.
Adverbial modifiers realized as prepositional phrases are 'nmod'.
If a word is tagged ADV, it should not end up attached as 'nmod'.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
