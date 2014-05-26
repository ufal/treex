#!/usr/bin/env perl

BEGIN {
    if ( ! $ENV{AUTHOR_TESTING}) {
        require Test::More;
        Test::More::plan( skip_all => 'these tests requires AUTHOR_TESTING' );
    }
}

use strict;
use warnings;
use utf8;

use Test::More tests=>4;
use Treex::Tool::Vallex::ValencyFrame;
note ('This may fail when valency lexicon changes');
{
    my $frame = Treex::Tool::Vallex::ValencyFrame->new( { id => 'v-w3f1', lexicon => 'vallex.xml', language => 'cs' } );
    #print $frame->to_string . "\n";
    is ($frame->to_string, 'abdikovat-v: ACT[n:1]', 'v-w3f1');

    $frame = Treex::Tool::Vallex::ValencyFrame->new( { id => 'v-w3351f3', lexicon => 'vallex.xml', language => 'cs' } );
    #print $frame->to_string . "\n";
    is ($frame->to_string, 'padat-v: ACT[n:1] (PAT[n:na+4]) (ORIG[n:z+2])', 'v-w3351f3');

    $frame = Treex::Tool::Vallex::ValencyFrame->new( { id => 'v-w3352f1', lexicon => 'vallex.xml', language => 'cs' } );
    #print $frame->to_string . "\n";
    is ($frame->to_string, 'padělání-n: ACT[n:7, n:2, adj:poss] PAT[n:2, adj:poss]', 'v-w3352f1');

    $frame = Treex::Tool::Vallex::ValencyFrame->new( { ord => '1000', lexicon => 'vallex.xml', language => 'cs' } );
    #print $frame->to_string . "\n";
    is ($frame->to_string, 'dohadování-n: ACT[n:2, adj:poss] PAT[v:jestli+fin, n:o+6, n:2, v:zda+fin] ADDR[n:s+7]', 'ord 1000');

}

__END__

=encoding utf-8

Valency Lexicon test -- load and print several random valency frames from the PDT-Vallex Czech valency lexicon.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
