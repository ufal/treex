#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Treex::Block::Read::Text;
use PerlIO::via::gzip;

my $value = int rand 100;    #get some random value
my $filename = 'text' . (int rand 100) . '.gz';
open my $f, '>:via(gzip)', $filename or die($!);                                #open it
print $f $value;                                                               #print there the value
close $f;
my $reader = Treex::Block::Read::Text->new( language => 'en', from => $filename );

my $doc = $reader->next_document();
is($doc->get_zone('en')->text, $value, q(Doc reader succesfully read generated value));
done_testing();
END {
    unlink $filename;
}
