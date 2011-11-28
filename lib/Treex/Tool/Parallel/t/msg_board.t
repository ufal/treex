#!/usr/bin/env perl
BEGIN {
  if (!$ENV{EXPERIMENTAL}) {
    require Test::More;
    Test::More::plan(skip_all => 'This test is experimental');
  }
}

use strict;
use warnings;

use Test::More;

BEGIN { use_ok('Treex::Tool::Parallel::MessageBoard') }

my $number_of_sharers = 4;
my $first_sharer = Treex::Tool::Parallel::MessageBoard->new( current => 1,
                                                             sharers => $number_of_sharers,
                                                         );
my @sharers = ($first_sharer,
    map { Treex::Tool::Parallel::MessageBoard->new(
        current => $_,
        sharers => $number_of_sharers,
        workdir => $first_sharer->workdir,
    ) } (2..$number_of_sharers)
);


my $sent_message = { this => [qw(is a test message)] };

# each but last sharer writes a message to the message board
for my $i (0..$number_of_sharers-2) {
    $sharers[$i]->write_message( $sent_message );
}

my @accepted_messages = $sharers[-1]->read_messages();

is_deeply($accepted_messages[0], $sent_message, 'hash structure correctly transfered via the message board');
ok( @accepted_messages == $number_of_sharers-1, 'messages from all talkers correctly transfered' );

done_testing();
