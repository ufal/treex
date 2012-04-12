package Treex::Block::A2A::GRC::AgdtFixAfun;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %AFUN_FOR = (
    PRED  => 'Pred',
    PNOM  => 'Pnom',
    SBJ   => 'Sb',
    OBJ   => 'Obj',
    ATR   => 'Atr',
    ADV   => 'Adv',
    ATV   => 'Atv',
    OCOMP => 'OComp',
);

sub process_anode {
    my ($self, $anode) = @_;
    my $new_afun = $AFUN_FOR{$anode->afun};
    if ($new_afun){
        $anode->set_afun($new_afun);
    }
    return;
}


__END__

=encoding utf-8

1;

=head1 NAME

Treex::Block::A2A::GRC::AgdtFixAfun - 

=head1 DESCRIPTION

Ancient Greek Dependency Treebank a-layer is almost PDT-compatible except for afun values
which are sometimes in all-capital.
This block converts the values to those defined in treex schema.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.