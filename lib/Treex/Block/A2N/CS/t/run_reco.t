#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
#use Test::Output;
use Data::Dumper;
use Treex::Core::Common;
use Treex::Core::Document;
use Treex::Core::Scenario;

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

eval { $scenario->end() };
ok( !$@, 'SysNERV scen end' ) or diag($@);



# save


# Featurama testing:
use_ok('Treex::Tool::Tagger::Featurama::CS');

my $tagger = Treex::Tool::Tagger::Featurama::CS->new();
my ($tags, $lemmas) = $tagger->tag_sentence( [qw/Pepa pase kozu ./] );

#Fixing utf-8 bug in Test::Builder (http://www.effectiveperlprogramming.com/blog/1226):
foreach my $method ( qw/output failure_output/ ) {
    binmode Test::More->builder->$method(), ':encoding(UTF-8)';
}

cmp_ok( scalar @$tags, '==', 4, q{Correct number of tags in testing sentence "Pepa pase kozu ."});
cmp_ok( scalar @$lemmas, '==', 4, q{Correct number of lemmas in testing sentence "Pepa pase kozu ."});
note( join ' ', @$tags );
note( join ' ', @$lemmas );

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
