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

use Treex::Tool::Parallel::MessageBoard;
use DateTime;
use DateTime::Duration;


my $number_of_sharers = 2;
my $first_sharer = Treex::Tool::Parallel::MessageBoard->new(
    current => 1,
    sharers => $number_of_sharers,
);

if ( fork == 0 ) { # child process
    my $second_sharer = Treex::Tool::Parallel::MessageBoard->new(
        current => 2,
        sharers => $number_of_sharers,
        workdir => $first_sharer->workdir,
    );
    sleep 2;
    $second_sharer->synchronize;
}

else { # parent process

    $first_sharer->synchronize;
#    ok ($time_after - $time_before > $diff, 'waiting for synchronization took expected time');
}
