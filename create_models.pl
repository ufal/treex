#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use autodie;

use Storable;

#use Data::Dump qw(dump);

use LanguageModel::Lemma;

# Lemma ids are read from share by default.
# However, we want to use lemma ids from the current dir.
# This way it is not necessary to overwrite old lemma ids in share.
LanguageModel::Lemma::_load_from_plsgz('lemma_id.pls.gz');

my $LOG2 = log 2;
sub log2 { sprintf( "%.4f", log( $_[0] ) / $LOG2 ); }

my ( $total, $sPg, $sLd, $sLg, $sFd, $sPd_Fd, $sFd_Pg, $sFd_Lg, $sLd_Fd, $sLdFd_Lg );
my $MIN_COUNT_FOR_MAIN_MODEL = 10;
my $EXPECTED_LEMMAS   = 150_000;
my $EXPECTED_FORMEMES = 1_5000;
foreach ( $sLd, $sLg, $sFd_Lg, $sLdFd_Lg ) { $_->[$EXPECTED_LEMMAS] = undef; }
foreach ( $sFd, $sPd_Fd, $sLd_Fd ) { keys %{$_} = $EXPECTED_FORMEMES; }

print STDERR "Reading input...\n";
binmode STDIN, ':utf8';
while (<STDIN>) {
    chomp;
    my ( $count, $Lg, $Pg, $Ld, $Pd, $Fd ) = split /\t/, $_;
    my $LdPd = LanguageModel::Lemma->new( $Ld, $Pd );
    my $LgPg = LanguageModel::Lemma->new( $Lg, $Pg );
    $total                 += $count;
    $sPg->{$Pg}            += $count;
    $sLd->[$$LdPd]         += $count;
    $sLg->[$$LgPg]         += $count;
    $sFd->{$Fd}            += $count;
    $sPd_Fd->{$Fd}{$Pd}    += $count;
    $sFd_Pg->{$Pg}{$Fd}    += $count;
    $sFd_Lg->[$$LgPg]{$Fd} += $count;
    $sLd_Fd->{$Fd}{$$LdPd} += $count;

    $sLdFd_Lg->[$$LgPg]{$$LdPd}{$Fd} = $count if $count > $MIN_COUNT_FOR_MAIN_MODEL;
}
my $logtotal = log2($total);
print STDERR "Total = $total edges, min logprob = -$logtotal\n";

print STDERR "Normalizing models: ";
print STDERR "Pg, ";
foreach ( values %{$sPg} ) { $_ = log2($_) - $logtotal; }
print STDERR "Ld, ";
foreach ( @{$sLd} ) { $_ = log2($_) - $logtotal if $_; }
print STDERR "Lg, ";
foreach ( @{$sLg} ) { $_ = log2($_) - $logtotal if $_; }
print STDERR "Fd, ";
foreach ( values %{$sFd} ) { $_ = log2($_) - $logtotal; }

print STDERR "Pd_Fd, ";
foreach my $Fd ( keys %{$sPd_Fd} ) {
    my $logFd = $sFd->{$Fd};
    foreach ( values %{ $sPd_Fd->{$Fd} } ) { $_ = log2($_) - $logtotal - $logFd; }
}

print STDERR "Fd_Pg, ";
foreach my $Pg ( keys %{$sFd_Pg} ) {
    my $logPg = $sPg->{$Pg};
    foreach ( values %{ $sFd_Pg->{$Pg} } ) { $_ = log2($_) - $logtotal - $logPg; }
}

print STDERR "Fd_Lg, ";
foreach my $iLg ( 1 .. @{$sFd_Lg} ) {
    my $Fd_ref = $sFd_Lg->[$iLg] or next;
    my $logLg = $sLg->[$iLg];
    foreach ( values %{$Fd_ref} ) { $_ = log2($_) - $logtotal - $logLg; }
}

print STDERR "Ld_Fd, ";
foreach my $Fd ( keys %{$sLd_Fd} ) {
    my $logFd = $sFd->{$Fd};
    foreach ( values %{ $sLd_Fd->{$Fd} } ) { $_ = log2($_) - $logtotal - $logFd; }
}

print STDERR "LdFd_Lg...";
foreach my $iLg ( 1 .. @{$sLdFd_Lg} ) {
    my $LdFd_ref = $sLdFd_Lg->[$iLg] or next;
    my $logLg = $sLg->[$iLg];
    foreach my $Fd_ref ( values %{$LdFd_ref} ){
        foreach ( values %{$Fd_ref} ) { $_ = log2($_) - $logtotal - $logLg; }
    }
}


print STDERR "\nSaving...\n";

#store_to_plsgz( $sPg, 'model_Pg.pls.gz' );
#store_to_plsgz( $sFd, 'model_Fd.pls.gz' );
#store_to_plsgz( $sLg,    'model_Lg.pls.gz' );
store_to_plsgz( $sLd,    'model_Ld.pls.gz' );
store_to_plsgz( $sPd_Fd, 'model_Pd_Fd.pls.gz' );
store_to_plsgz( $sFd_Pg, 'model_Fd_Pg.pls.gz' );
store_to_plsgz( $sFd_Lg, 'model_Fd_Lg.pls.gz' );
store_to_plsgz( $sLd_Fd, 'model_Ld_Fd.pls.gz' );
store_to_plsgz( $sLdFd_Lg, 'model_LdFd_Lg.pls.gz' );

sub store_to_plsgz {
    my ( $model, $filename ) = @_;
    open my $PLSGZ, '>:gzip', $filename;
    Storable::nstore_fd( $model, $PLSGZ );
    close $PLSGZ;
    return;
}

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.