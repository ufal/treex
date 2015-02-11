#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

use Treex::Tool::LM::Lemma;
use Treex::Tool::LM::TreeLM;
my $path = $ENV{TMT_ROOT}.'/share/data/models/language/cs/';
my $model = Treex::Tool::LM::TreeLM->new({ dir => $path });
Treex::Tool::LM::Lemma::init("$path/lemma_id.pls.gz");

my @queries = (
 #['být V',            'pes N',             'n:1'],
 #['ministerstvo N',   'školství N',        'n:2'],
 #['ministerstvo N',   'vzdělávání N',      'n:2'],
 #['poznat V',         'svět N',            'n:4'],
 #['ztektoemtizovat V','svět N',            'n:4'],
 #['_ROOT #',          'poznat V',          'v:fin'],
 #['_ROOT #',          'ztektoemtizovat V', 'v:fin'],
 #['_ROOT #',          'přidat V',          'v:fin'],
 #['_ROOT #',          'dodat V',           'v:fin'],
 #['přidat V',         'Baumohl N',         'n:subj'],
 #['dodat V',          'Baumohl N',         'n:subj'],
 ['Londýn N',          'používat V',      'v:rc'],
 ['Londýn N',          'zaměstnávat V',   'v:rc'],
 ['používat V',        'banka N',          'n:1'],
 ['zaměstnávat V',     'banka N',          'n:1'],
 ['používat V',        'člověk N',         'n:2'],
 ['zaměstnávat V',     'člověk N',         'n:2'],
 ['používat V',        'kde D',          'adv:'],
 ['zaměstnávat V',     'kde D',          'adv:'],
);

foreach my $query_ref (@queries){
    print "\n";
    my ($uLg, $uLd, $Fd) = @{$query_ref};
    my $Lg = Treex::Tool::LM::Lemma->new($uLg);
    my $Ld = Treex::Tool::LM::Lemma->new($uLd);
    my $probLdFd_Lg = $model->get_prob_LdFd_given_Lg($Ld,$Fd,$Lg,1);
}

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.