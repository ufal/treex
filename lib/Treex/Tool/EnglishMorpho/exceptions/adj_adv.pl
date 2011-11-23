#!/usr/bin/env perl
my $DATA = <<'END_DATA';
better	JJR	good
best	JJS	good
worse	JJR	bad
worst	JJS	bad
further	JJR	far
furthest	JJS	far
elder	JJR	old
eldest	JJS	old
stranger	JJR	strange
strangest	JJS	strange
better	RBR	well
best	RBS	well
worse	RBR	badly
worst	RBS	badly
further	RBR	far
furthest	RBS	far
END_DATA

if   ( $ARGV[0] =~ /^-[ad]$/ ) { print $DATA; }
else                           { die "Invalid usage: use option -a or -d\n"; }
