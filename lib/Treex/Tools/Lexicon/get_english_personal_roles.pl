#!/usr/bin/perl

use strict;
use warnings;

use TranslationModel::Static::Model;

my %cs_roles;

open (CS, "<:encoding(utf-8)", "$ENV{TMT_ROOT}/libs/other/Lexicon/czech_personal_roles.txt") or die;
while (<CS>) {
    chomp;
    $cs_roles{$_} = 1;
}
close CS;

my $MODEL_STATIC = 'data/models/translation/en2cs/tlemma_czeng09.static.pls.gz';
my $static_model = TranslationModel::Static::Model->new();
$static_model->load("$ENV{TMT_ROOT}/share/$MODEL_STATIC");

open (EN, "<:encoding(utf-8)", "$ENV{TMT_ROOT}/share/generated_data/extracted_from_BNC/personal_roles.tsv") or die;
while (<EN>) {
    chomp;
    my @items = split (/\t/, $_);
    my @translations = $static_model->get_translations($items[0]);
    foreach my $tr (@translations) {
        $tr->{label} =~ s/#.$//;
        if ($cs_roles{$tr->{label}}) {
            print "$items[0]\n";
        }
    }
}
close EN;



