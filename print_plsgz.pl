#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use autodie;
use PerlIO::gzip;
use Storable;
use Data::Dumper;
my $filename = shift or die "No filename as argument\n";
open my $IN, ($filename =~ /\.gz$/) ? '<:gzip' : '<', $filename;
my $model = Storable::fd_retrieve($IN) or die 'Can not read Storable.';
close $IN;
print Dumper($model);

# Copyright 2009 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.