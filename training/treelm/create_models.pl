#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use autodie;

use Storable;
use LanguageModel::Lemma;

my $ALL                      = '<ALL>';
my $MIN_COUNT_FOR_MAIN_MODEL = 4;
my $EXPECTED_LEMMAS          = 150_000;
my $EXPECTED_FORMEMES        = 1_500;

# Lemma ids are read from share by default.
# However, we want to use lemma ids from the current dir.
# This way it is not necessary to overwrite old lemma ids in share.
# TODO: uncomment next line
LanguageModel::Lemma::_load_from_plsgz('lemma_id.pls.gz');

# Allocate enough memory for models, so no rehashing or array re-allocation is needed
my ( $total, $cLgFdLd, $cPgFdLd );
$cLgFdLd->[$EXPECTED_LEMMAS] = undef;
keys %{$cPgFdLd} = $EXPECTED_FORMEMES;

print STDERR "Reading input...\n";
binmode STDIN, ':utf8';
while (<STDIN>) {
    chomp;
    my ( $count, $Lg, $Pg, $Ld, $Pd, $Fd ) = split /\t/, $_;
    my $LdPd = LanguageModel::Lemma::get_indexed( $Ld, $Pd ) or die "'$Ld $Pd' not indexed.";
    my $LgPg = LanguageModel::Lemma::get_indexed( $Lg, $Pg ) or die "'$Lg $Pg' not indexed.";
    $total                         += $count;
    $cPgFdLd->{$Pg}{$ALL}          += $count;
    $cPgFdLd->{$Pg}{$Fd}{$ALL}     += $count;
    $cPgFdLd->{$Pg}{$Fd}{$$LdPd}   += $count;
    $cPgFdLd->{$ALL}{$ALL}{$$LdPd} += $count;
    $cPgFdLd->{$ALL}{$Fd}{$ALL}    += $count;
    $cPgFdLd->{$ALL}{$Fd}{$$LdPd}  += $count;

    $cLgFdLd->[$$LgPg]{$ALL}        += $count;
    $cLgFdLd->[$$LgPg]{$Fd}{$ALL}   += $count;
    $cLgFdLd->[$$LgPg]{$Fd}{$$LdPd} += $count if $count >= $MIN_COUNT_FOR_MAIN_MODEL;
}
$cPgFdLd->{$ALL}{$ALL}{$ALL} = $total;

print STDERR "Total = $total edges\n";
print STDERR "Saving...\n";

store_to_plsgz( $cLgFdLd, 'c_LgFdLd.pls.gz' );
store_to_plsgz( $cPgFdLd, 'c_PgFdLd.pls.gz' );

sub store_to_plsgz {
    my ( $model, $filename ) = @_;
    open my $PLSGZ, '>:gzip', $filename;
    Storable::nstore_fd( $model, $PLSGZ );
    close $PLSGZ;
    return;
}

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
