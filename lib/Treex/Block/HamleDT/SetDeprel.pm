package Treex::Block::HamleDT::SetDeprel;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



#------------------------------------------------------------------------------
# Makes sure that whatever attribute of the a-node is used to store the type of
# the incoming edge, it will be moved to deprel. The possible source attributes
# are tried following a priority list, and the first defined value is used. All
# such attributes other than deprel are then undefined to decrease potential
# for confusion. (The motivation for this block is that various data readers
# put the edge label in various places and we need to unify them.)
#------------------------------------------------------------------------------
sub process_anode
{
    my $self   = shift;
    my $node   = shift;
    my $deprel = $node->deprel();
    $deprel = $node->afun() if(!defined($deprel));
    $deprel = $node->conll_deprel() if(!defined($deprel));
    $deprel = 'NR' if(!defined($deprel));
    $node->set_deprel($deprel);
    $node->set_afun(undef);
    $node->set_conll_deprel(undef);
}



1;

=over

=item Treex::Block::HamleDT::SetDeprel

Scans a-node attributes that various data readers may have used to store the
label of the incoming edge, and makes sure the label is stored in the deprel
attribute, while the other competing attributes (afun, conll/deprel) are undefined.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2025 by Institute of Formal and Applied Linguistics, Charles University, Prague.

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
