package Treex::Block::Write::Text;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

#TODO implement "to"
has to => ( isa => 'Str', is => 'ro', default => '-' );

sub process_zone {
    my ( $self, $zone ) = @_;
    print $zone->text;
}

1;
