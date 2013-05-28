#!/usr/bin/env perl

use strict;
use warnings;
use utf8;

use Test::More;
#use Test::Output;
use Data::Dumper;
use Treex::Core::Common;
use Treex::Core::Document;
use Treex::Core::Scenario;
use Treex::Tool::NamedEnt::Features::Common qw/:tests/;
use Treex::Tool::Lexicon::CS;


#Fixing utf-8 bug in Test::Builder (http://www.effectiveperlprogramming.com/blog/1226):
foreach my $method ( qw/output failure_output/ ) {
    binmode Test::More->builder->$method(), ':encoding(UTF-8)';
}

#BEGIN { use_ok ( 'Treex::Block::A2N::CS::SysNERV' ) };

my @sentence1 = qw/Premiér Petr Nečas se dnes ve 14 hodin sešel se svými kolegy v Praze a za týden se setká v Teplicích v Krupské ulici s hejtmanem ústeckého kraje ./;

my $document = Treex::Core::Document->new;
my $bundle = $document->create_bundle();
my $aroot = $bundle->create_tree('cs', 'A');

my $i = 0;
for my $word (@sentence1) {
    my $nosp = 1;
    $nosp = 0 if $word eq 'kraje';
    $aroot->create_child(form=>$word, no_space_after=>$nosp, ord=>++$i);
}

my $scenario;

eval { $scenario = Treex::Core::Scenario->new(from_string => 'W2A::CS::TagFeaturama lemmatize=1 A2N::CS::SysNERV') };
ok( !$@, 'SysNERV scen build' ) or diag($@);

eval { $scenario->start() };
ok( !$@, 'SysNERV scen start' ) or diag($@);

eval {$scenario->apply_to_documents($document)};
ok( !$@, 'Run SysNERV recognition' ) or diag($@);

ok(is_listed_entity(qw/ leden months/), 'leden is a month');
ok(is_listed_entity(qw/ prosinec months/), 'prosinec is a month');
ok(!is_listed_entity(qw/ květňák months/), 'květňák is not a month');
ok(is_listed_entity(qw/ Praha cities/), 'Praha is a city');
ok(is_listed_entity(qw/ Loučovice cities/), 'Loučovice is a city');
my @list = ('Malá strana', 'city_parts');
ok(is_listed_entity(@list), 'Malá strana is a city part'); # why not OK? -- problem with diacritics?? why not used binmode in Common.pm??
ok(is_listed_entity(qw/ Dejvice city_parts/), 'Dejvice is a city part');
ok(is_listed_entity(qw/ Dejvická streets/), 'Dejvická is a street'); # no list with streets?
ok(is_listed_entity(qw/ Legerova streets/), 'Legerova is a street'); # no lis with streets?
ok(is_listed_entity(qw/ Petra first_names/), 'Petra is a first name');
ok(is_listed_entity(qw/ Petr first_names/), 'Petr is a first name');
ok(is_listed_entity(qw/ Jindřich first_names/), 'Jindřich is a first name'); # why not OK? 
ok(is_listed_entity(qw/ Ondřej first_names/), 'Ondřej is a first name'); # why not OK?
ok(is_listed_entity(qw/ Jan first_names/), 'Jan is a first name');
ok(is_listed_entity(qw/ Sára first_names/), 'Sára is a first name'); # why not OK?
ok(is_listed_entity(qw/ Novák surnames/), 'Novák is a surname'); # why not OK?
ok(is_listed_entity(qw/ Černá countries/), 'Nováková is a surname'); # why not OK?
ok(is_listed_entity(qw/ Dánsko countries/), 'Dánsko is a country'); # why not OK?
ok(is_listed_entity(qw/ Egypt countries/), 'Egypt is a country');
ok(is_listed_entity(qw/ Švýcarsko countries/), 'Švýcarsko is a country'); # why not OK?
ok(is_listed_entity(qw/ USD objects/), 'USD is an object'); # no list with objects?
ok(is_listed_entity(qw/ NATO institutions/), 'NATO is an institution'); # no list with institutions?

ok((get_class_number('a') == 0) ? 1 : 0, 'a is the first class');
ok((get_class_number('c') == 4) ? 1 : 0, 'c is the fifth class');
ok((get_class_number('m') == 27) ? 1 : 0, 'm is the twenty-eighth class');

ok((get_class_from_number(2) eq 'at') ? 1 : 0, 'third class is "at"');
ok((get_class_from_number(10) eq 'g') ? 1 : 0, 'eleventh class is "g"');

ok(is_tabu_pos('J'), 'J probably isn\'t NE');
ok(is_tabu_pos('R'), 'R probably isn\'t NE');
ok(!is_tabu_pos('N'), 'N can be NE');
ok(!is_tabu_pos('C'), 'C can be NE');

my %list_names = map { $_ => 1} get_built_list_names;
ok(exists($list_names{'months'}), 'months list OK');
ok(exists($list_names{'cities'}), 'cities list OK');
ok(exists($list_names{'city_parts'}), 'city parts list OK');
ok(exists($list_names{'streets'}), 'streets list OK');
ok(exists($list_names{'first_names'}), 'firstnames list OK');
ok(exists($list_names{'surnames'}), 'surnames list OK');
ok(exists($list_names{'countries'}), 'countries list OK');
ok(exists($list_names{'objects'}), 'objects list OK');
ok(exists($list_names{'institutions'}), 'institutions list OK');
ok(exists($list_names{'clubs'}), 'clubs list OK');



ok(is_year_number('1988'), '1988 is a year number...');
ok(is_year_number('2013'), '2013 is a year number ...');
ok(!is_year_number('348'), '348 is not a year number...'); # Really??
ok(!is_year_number('3348'), '3348 is not a year number...');


ok(is_month_number('5'), '5 is a month number...');
ok(is_month_number('10'), '10 is a month number...'); # Corrected
ok(is_month_number('12'), '12 is a month number...');
ok(!is_month_number('13'), '13 is not a month number...');


ok(is_day_number('7'), '7 is a day number...');
ok(is_day_number('13'), '13 is a day number...');
ok(is_day_number('22'), '22 is a day number...');
ok(is_day_number('30'), '30 is a day number...');
ok(is_day_number('31'), '31 is a day number...');
ok(!is_day_number('32'), '32 is not a day number...');
ok(!is_day_number('122'), '122 is not a day number...');

eval { $scenario->end() };
ok( !$@, 'SysNERV scen end' ) or diag($@);



# save


# Featurama testing:
#use_ok('Treex::Tool::Tagger::Featurama::CS');
#
#my $tagger = Treex::Tool::Tagger::Featurama::CS->new();
#my ($tags, $lemmas) = $tagger->tag_sentence( [qw/Pepa pase kozu ./] );

#
#cmp_ok( scalar @$tags, '==', 4, q{Correct number of tags in testing sentence "Pepa pase kozu ."});
#cmp_ok( scalar @$lemmas, '==', 4, q{Correct number of lemmas in testing sentence "Pepa pase kozu ."});
#note( join ' ', @$tags );
#note( join ' ', @$lemmas );

# large input testing:
#my $file = "large.file";
#open (my $INPUT, $file) or die "Cannot open file \"large.file\" for testing...";
#binmode $INPUT, 'encoding(UTF-8)';
#while (<$INPUT>) {
#    my ($t, $l) = $tagger->tag_sentence( [split /[\s+\.,!\?]/, $_] );
#    note (join ' ', @$t );
#    note (join ' ', @$l );
#    exit if $. > 5;
#    print "\n";
#    my @a = split /[\s+\.,!\?]/, $_;
#    print Dumper(@a);
#}
#
#print "OK! Tagging complete.\n";


done_testing();
