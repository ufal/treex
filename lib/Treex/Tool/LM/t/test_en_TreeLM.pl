#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';

use Treex::Tool::LM::Lemma;
use Treex::Tool::LM::TreeLM;
my $path = $ENV{TMT_ROOT}.'/share/data/models/language/en.czeng_third/';
my $model = Treex::Tool::LM::TreeLM->new({ dir => $path });
Treex::Tool::LM::Lemma::init("$path/lemma_id.pls.gz");

my @queries = (
 ['be verb',         'year noun',          'n:subj'],
 ['ministry noun',   'education noun',     'n:of+X'],
 ['ministry noun',   'education noun',     'n:attr'],
 ['ministry noun',   'schooling noun',     'n:of+X'],
 ['rareverb verb',   'world noun',         'n:obj'],
 ['rareverb verb',   'rarenoun noun',      'n:obj'],
 ['_ROOT #',         'know verb',          'v:fin'],
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