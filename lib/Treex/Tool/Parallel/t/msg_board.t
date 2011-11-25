#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN { use_ok('Treex::Tool::Parallel::MessageBoard') }

my $number_of_sharers = 4;
my @sharers = map { Treex::Tool::Parallel::MessageBoard->new(directory=>'.',
                                                             number=>$_,
                                                             sharers=> $number_of_sharers,
                                                         ) } (1..$number_of_sharers);
$sharers[0]->init;

my $sent_message = { this => [qw(is a test message)] };

# each but last sharer writes a message to the message board
for my $i (0..$number_of_sharers-2) {
    $sharers[$i]->write_message( $sent_message );
}

my @accepted_messages = $sharers[-1]->read_messages();

is_deeply($accepted_messages[0], $sent_message, 'hash structure correctly transfered via the message board');
ok( @accepted_messages == $number_of_sharers-1, 'messages from all talkers correctly transfered' );

done_testing();
