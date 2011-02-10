#!/usr/bin/perl

use strict;
use warnings;

use Treex::Core::Document;

my $doc = Treex::Core::Document->new;

$doc->set_attr( 'description', 'This is a testing treex file' );
print "description: " . $doc->get_attr('description') . "\n";

$doc->set_attr( 'Sen text', 'John loves Mary. Mary loves John.' );
print "Sen text: " . $doc->get_attr('Sen text') . "\n";

$doc->save('test.tmt');
