#!/usr/bin/env perl

use strict;
use utf8;

use Treex::Tools::Lexicon::Derivations::CS;
binmode STDOUT,":utf8";

my %sample_input = (
    adj2adv => [qw(zelený sporý drahý plochý pracný zajímavý)],
    verb2noun => [qw(chodit platit hlídat smát)],
    noun2adj => [qw(hrad pes prach strom les matka Josef Praha Bush)],
    verb2adj => [qw(praštit vařit létat ušít skácet napsat)],
    verb2activeadj => [qw(chodit plavat klamat hořet)],
    perf2imperf => [qw(otevřít)],
    imperf2perf => [qw(dosahovat)],
);


foreach my $type (keys %sample_input) {
    print "Derivations of type $type\n";
    foreach my $input (@{$sample_input{$type}}) {
        print "\t$input --> " . join (", ",Treex::Tools::Lexicon::Derivations::CS::derive($type,$input))."\n";
    }
}
