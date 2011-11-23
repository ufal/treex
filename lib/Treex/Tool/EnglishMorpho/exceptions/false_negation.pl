#!/usr/bin/env perl
my $DATA = <<'END_DATA';
nonetheless	RB	nonetheless
none-the-less	RB	nonetheless
nonchalance	NN	nonchalance
nonchalant	JJ	nonchalant
noncommittal	JJ	noncommittal
noncommittally	RB	noncommittally
nonsense	NN	nonsense
nonsenses	NN	nonsenses
nonstop	NN	nonstop
non-stop	NN	nonstop
END_DATA

if   ( $ARGV[0] =~ /^-[ad]$/ ) { print $DATA; }
else                           { die "Invalid usage: use option -a or -d\n"; }
