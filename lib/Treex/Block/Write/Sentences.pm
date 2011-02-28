package Treex::Block::Write::Sentences;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

has encoding => (
    is => 'ro',
    default => 'utf8',
    documentation => 'Output encoding. By default utf8.',
);

sub BUILD {
    my ($self) = @_;
    binmode STDOUT, ':encoding(' . $self->encoding . ')';
}

sub process_zone {
    my ( $self, $zone ) = @_;
    print $zone->sentence, "\n";
}

1;

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
