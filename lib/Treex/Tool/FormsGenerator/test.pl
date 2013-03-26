#!/usr/bin/env perl

use utf8;
use strict;
use warnings;

use Treex::Tool::FormsGenerator::Tamil;

# generate all verb forms of : அழு ('to cry')
my $generator = Treex::Tool::FormsGenerator::Tamil->new( use_template => 'verb_type1');
my @forms_type1 = $generator->generate_forms('அழு');

# generate all verb forms of : விழு ('to fall')
$generator->set_template('verb_type2');
my @forms_type2 = $generator->generate_forms('விழு');

# generate all verb forms of : செல் ('to go')
$generator->set_template('verb_type2a');
my @forms_type2a = $generator->generate_forms('செல்');

# generate all verb forms of : தூங்கு ('to sleep')
$generator->set_template('verb_type3');
my @forms_type3 = $generator->generate_forms('தூங்கு');

# generate all verb forms of : போடு ('to put')
$generator->set_template('verb_type4');
my @forms_type4 = $generator->generate_forms('போடு');

# generate all verb forms of : கேள் ('to listen'), ஏல்('to accept')
$generator->set_template('verb_type5');
my @forms_type51 = $generator->generate_forms('கேள்');
my @forms_type52 = $generator->generate_forms('ஏல்');

# generate all verb forms of : அமை ('to build')
$generator->set_template('verb_type6');
my @forms_type6 = $generator->generate_forms('அமை');

# generate all verb forms of : நட ('to walk')
$generator->set_template('verb_type7');
my @forms_type7 = $generator->generate_forms('நட');


print "# verb forms of : அழு ('to cry')\n";
map{print $_ . "\n"}@forms_type1;

print "# verb forms of : விழு ('to fall')\n";
map{print $_ . "\n"}@forms_type2;

print "# verb forms of :  செல் ('to go')\n";
map{print $_ . "\n"}@forms_type2a;

print "# verb forms of : தூங்கு ('to sleep')\n";
map{print $_ . "\n"}@forms_type3;

print "# verb forms of : போடு ('to put')\n";
map{print $_ . "\n"}@forms_type4;

print "# verb forms of : கேள் ('to listen')\n";
map{print $_ . "\n"}@forms_type51;

print "# verb forms of : ஏல்('to accept')\n";
map{print $_ . "\n"}@forms_type52;

print "# verb forms of : அமை ('to build')\n";
map{print $_ . "\n"}@forms_type6;

print "# verb forms of : நட ('to walk')\n";
map{print $_ . "\n"}@forms_type7;
