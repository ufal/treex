#!/usr/bin/env perl

=pod

=head1 NAME

TuneSVM.pl - script for tuning a SVM model

=head1 SYNOPSIS

TuneSVM.pl I<DATA>

=head1 DESCRIPTION

Finds the best combination of gamma and C parameters.

=cut

use strict;
use warnings;

use Text::Table;

use FileHandle;
#use IPC::Open2;
use threads;
use threads::shared;

use Pod::Usage;

my %accuracy;
share(%accuracy);

my @threads;

my @gamma_exps =  (-15, -13, -11, -9, -7, -5, -3, -1, 1, 3, 5);
my @c_exps = ( -5, -3, -1, 1, 3, 5, 7, 9, 11, 13, 15 );

my @gammas = map { 2 ** $_ } @gamma_exps;
my @cs = map { 2 ** $_ } @c_exps;

for my $gamma (@gammas) {
    for my $c (@cs) {

        my $thr = async {

            my $reader;

            my $pid = open($reader, "|-", "./tuneWrapper.sh --gamma=$gamma --c=$c"); # Pustime ulohu na gridu
#            my $pid = open($reader, "-|", "echo \"$gamma\"") or die 'Cannot open pipe';

            for (<$reader>) {   # Posbirame vysledky
                chomp;
                {
                    lock %accuracy;

		    if (!exists $accuracy{$gamma}) {
			$accuracy{$gamma} = &share({});
		    }

                    unless (exists $accuracy{$gamma}{$c}) {
                        $accuracy{$gamma}{$c} = $_;
                    }
                }
            }

            waitpid $pid, 0; # Pockame s ukoncenim vlakna na ukonceni ulohy v gridu
        };

        push @threads, $thr;
    }
}

for (@threads) {
    $_->join();
}

my $best_acc = 0;
my $best_gamma;
my $best_c;

my $table = Text::Table->new( ("Accuracy", @gammas) );

for my $c (@cs) {

    my @row = ($c);

    for my $gamma (@gammas) {
        my $acc = $accuracy{$gamma}{$c};

        if ($acc > $best_acc) {
            $best_acc = $acc;
            $best_gamma = $gamma;
            $best_c = $c;
        }

        push @row, $acc;
    }

    $table->load(\@row);
}

print "==================== RESULTS ==========================\n";
print $table;

print "\n";
print "Best gamma/c pair: Gamma $best_gamma, C $best_c\nBest accuracy: $best_acc\n\n";
