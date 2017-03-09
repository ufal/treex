package Treex::Block::A2A::Deprel2Afun;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ($self, $anode) = @_;
    my $afun = $anode->deprel;
    if ($afun =~ s/_(Co|Ap)//){
        if (($anode->get_parent->afun||'') =~ /Coord|Apos/){
            $anode->set_is_member(1);
        }
    }
    $anode->set_afun($afun);
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::Deprel2Afun

=head1 DESCRIPTION

Store anode->deprel into anode->afun
and convert the "_Co" and "_Ap" suffixes into anode->is_member.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
