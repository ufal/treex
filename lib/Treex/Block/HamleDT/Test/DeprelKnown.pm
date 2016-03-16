package Treex::Block::HamleDT::Test::DeprelKnown;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

# Treex uses 'NR' for unknown afun (Prague deprel) but we do not want it to occur in the data.
my @known_relations = qw(Pred Sb Obj Adv Atv AtvV Atr Pnom AuxV Coord AuxT AuxR
    AuxP AuxC AuxO AuxZ AuxX AuxG AuxY AuxS AuxK ExD
    AuxA Neg Apposition);

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $deprel = $node->deprel();
    if(!defined($deprel) || !any {$deprel eq $_} (@known_relations))
    {
        $self->complain($node, $deprel);
    }
    else
    {
        $self->praise($node);
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::DeprelKnown

This test makes sure that the C<deprel> attribute (dependency relation label)
is defined and that it contains one of the expected values for harmonized
Prague-style treebanks.

=back

=head1 AUTHOR

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
