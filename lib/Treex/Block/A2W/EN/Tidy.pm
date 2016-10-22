package Treex::Block::A2W::EN::Tidy;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has domain => (
     is => 'ro',
     isa => enum( [qw(general IT)] ),
     default => 'general',
     documentation => 'domain of the input texts',
);

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

    $sent =~ s/[“”]/"/g if $self->domain eq 'IT';

    $zone->set_sentence($sent);
    return;
}

1;

