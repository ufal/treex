#!/usr/bin/env perl
use strict;
use warnings;
use Treex::Tools::Tagger::TreeTagger;
use Test::More tests => 3;

my $tagger = Treex::Tools::Tagger::TreeTagger->new(model=> $ENV{TMT_ROOT} . 'share/data/models/tagger/tree_tagger/en.par');
isa_ok( $tagger, 'Treex::Tools::Tagger::TreeTagger', 'tagger instantiated' );

my @forms = qw(How are you ?);
my @expected_tags = qw(WRB VBP PP SENT);
my @expected_lemmas = qw(How be you ?);
my ($tags, $lemmas) = @{ $tagger->analyze(\@forms) };
is_deeply( $tags, \@expected_tags , 'tags ok' );
is_deeply( $lemmas, \@expected_lemmas , 'lemmas ok' );
