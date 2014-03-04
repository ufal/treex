package Treex::Block::A2A::SK::ConvertTagsToPDT;
use Moose;
use Treex::Core::Common;
use tagset::common;
use tagset::cs::pdt;

extends 'Treex::Core::Block';

sub process_anode {
    my ($self, $anode) = @_;

    return if (!$anode->tag);
    my $f = tagset::common::decode('sk::snk', $anode->tag);
    my $pdt_tag = tagset::cs::pdt::encode($f, 1);

    $anode->wild->{snk_tag} = $anode->tag;
    $anode->set_tag($pdt_tag);
}

1;
