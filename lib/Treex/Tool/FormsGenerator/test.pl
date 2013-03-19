#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Treex::Tool::FormsGenerator::Tamil;

my $generator = Treex::Tool::FormsGenerator::Tamil->new( use_template => 'verb_type1');
my @forms = $generator->generate_forms('அழு');
map{print $_ . "\n"}@forms;


