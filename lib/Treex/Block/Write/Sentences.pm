package Treex::Block::Write::Sentences;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

has encoding => (
    is            => 'ro',
    default       => 'utf8',
    documentation => 'Output encoding. By default utf8.',
);

has join_resegmented => (
    is            => 'ro',
    isa           => 'Bool',
    default       => 1,
    documentation => 'Print the sentences re-segmented'
        . ' by W2A::ResegmentSentences on one line.',
);

sub BUILD {
    my ($self) = @_;
    binmode STDOUT, ':encoding(' . $self->encoding . ')';
}

sub process_zone {
    my ( $self, $zone ) = @_;
    my $bundle_id = $zone->get_bundle()->id;
    if ( $self->join_resegmented && $bundle_id =~ /_(\d+)of(\d+)$/ && $1 != $2 ) {
        print $zone->sentence, " ";
    }
    else {
        print $zone->sentence, "\n";
    }
    return;
}

1;

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
