package Treex::Block::HamleDT::Test::UD::CompoundPrepositions;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    for(my $i = 0; $i <= $#nodes-2; $i++)
    {
        # Czech "na rozdíl od" is a compound preposition. The first token should be head, the second and the third token should depend on it as mwe.
        my $trigram = join(' ', map {lc($_->form())} (@nodes[$i..($i+2)]));
        if($trigram eq 'na rozdíl od')
        {
            if($nodes[$i+1]->parent() == $nodes[$i] && $nodes[$i+1]->conll_deprel() eq 'mwe' &&
               $nodes[$i+2]->parent() == $nodes[$i] && $nodes[$i+2]->conll_deprel() eq 'mwe)
            {
                $self->praise($node);
            }
            else
            {
                $self->complain($node, $trigram);
            }
            $i += 2;
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::Test::UD::CompoundPrepositions

Check the analysis of Czech compound prepositions such as I<na rozdíl od>.
The first token should be head, the second and the third token should depend on it as a C<mwe>.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
