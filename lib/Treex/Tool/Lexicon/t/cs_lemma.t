#!/usr/bin/env perl
use utf8;
use strict;
use warnings;
use Test::More;

# http://www.effectiveperlprogramming.com/blog/1226
if( Test::Builder->VERSION < 2 ) {
    foreach my $method ( qw(output failure_output) ) {
        binmode Test::More->builder->$method(), ':encoding(UTF-8)';
    }
}

use_ok 'Treex::Tool::Lexicon::CS';

my $TEST = <<'END';
pes_^(zvíře)                                   pes
jeden`1                                        jeden
sto-1`100_^(bez_sto_mužů,_sto_dětem,...)       sto-1
Praha_;G                                       Praha
stát-3_^(někdo/něco_stojí,_např._na_nohou)     stát-3
se_^(zvr._zájmeno/částice)                     se
C'-tung                                        C'-tung
d-4_^(př._d'Artagnan,_stažený_tvar_fr._předl.) d-4
Martinův-1_;Y_^(*4-1)                          Martinův-1
kWh-1`kilowatthodina_:B                        kWh-1
post-3_,t_^(lat.,_po,_ex_post)                 post-3
UK-1_:B_;K_^(Univerzita_Karlova_Praha)         UK-1
be_,t_^(angl._být,_v_názvech_apod.)            be
;   ;
:   :
`   `
`a  `a
END
# ČNK contains "`a la" instead of "à la"

for my $line (split /\n/, $TEST){
    chomp $line;
    my ($lemma, $gold) = split / +/, $line;
    my $predicted = Treex::Tool::Lexicon::CS::truncate_lemma($lemma);
    is($predicted, $gold, sprintf("%50s -> $predicted", $lemma));
}

done_testing();