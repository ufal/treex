package Treex::Block::W2A::FixNonleafAuxC;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ($self, $anode) = @_;
    if ($anode->afun eq 'AuxC' && !$anode->get_echildren()) {

        # Coordinated AuxC may have shared modifiers ("to and from Prague")
        # or it may be a phrase ("Companies move in and out.").
        # Let's skip such cases.
        return if $anode->is_member;
        
        # Multi-word AuxC should have all but the last word as leaves.
        # Let's skip such cases.
        my $parent  = $anode->get_parent();
        return if $parent->afun eq 'AuxC';
        
        my $grandpa = $parent->get_parent() or return;
        $anode->set_parent($grandpa);
        $parent->set_parent($anode);
        $anode->set_is_member($parent->is_member);
        $parent->set_is_member(0);
    }
    return;
}

1;

__END__

=head1 NAME

Treex::Block::W2A::FixNonleafAuxC - nodes with afun AuxC must have children

=head1 DESCRIPTION

Nodes with afun AuxC (subordinating conjunctions)
should always govern "their verb", e.g.
"He said that(afun=AuxC, parent=said) it is(parent=that) true."

This block rehangs all AuxC nodes without effective children between
their original parent and grandparent. So it fixes cases like
"He said that(afun=AuxC, parent=is) it is(parent=said) true."

Multi-word AuxC should have all but the last word as leaves,
so these cases are left unchanged.

=head1 SEE ALSO

L<Treex::Block::Test::A::NonleafAuxC>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
