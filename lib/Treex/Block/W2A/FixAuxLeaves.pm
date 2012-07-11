package Treex::Block::W2A::FixAuxLeaves;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ($self, $anode) = @_;
    if ($anode->afun =~ /^Aux[XART]$/) {
        foreach my $child ($anode->get_children()){
           $child->set_parent($anode->get_parent()); 
        }
    }
    return;
}

1;

__END__

=head1 NAME

Treex::Block::W2A::FixAuxLeaves - nodes with afun=~/Aux[XART]/ cannot have children

=head1 DESCRIPTION

Nodes with afun AuxX (non-coordinating comma),
AuxA (article),
AuxR (passive reflexive particle), and
AuxT (reflexive tantum particle)
should be always leafs of the dependency tree.
This block rehangs all children of such nodes to the parent of the Aux[XART] node.

=head1 SEE ALSO

L<Treex::Block::Test::A::LeafAux>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
