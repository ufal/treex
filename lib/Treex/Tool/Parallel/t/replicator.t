#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN { use_ok('Treex::Tool::Parallel::Replicator') }

my $number_of_replicants = 10;
my $replicator = Treex::Tool::Parallel::Replicator->new( replicants => $number_of_replicants );

if ( $replicator->is_hub ) {

    $replicator->synchronize; # wait for all replicants to reach the synchronization point

    my @accepted_messages = $replicator->message_board->read_messages();
    cmp_ok( scalar @accepted_messages, '==', $number_of_replicants, 'messages received from all replicants' );
}

else {
    $replicator->message_board->write_message({message=>"from replicant ".$replicator->current()});
    $replicator->synchronize;
}

done_testing();
