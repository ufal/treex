package Treex::Block::A2W::EN::Tidy;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;

    my $sent = $zone->sentence;

    $sent =~ s/,+/,/g;
    $sent =~ s/,\././g;
    $sent =~ s/,?",/,"/g;
    $sent =~ s/,":/":/g;
    $sent =~ s/:,/:/g;
    $sent =~ s/(,")+/,"/g;

    $sent =~ s/([0-9]+),([0-9]*[1-9]+[0-9]*)/$1.$2/g;

    $zone->set_sentence($sent);
    return;
}

1;

