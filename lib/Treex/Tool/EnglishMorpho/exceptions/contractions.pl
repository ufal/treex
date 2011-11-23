#!/usr/bin/env perl
# 's VBZ can be lemmatized both as "be" and "have".
# According to BNC, "be" is more frequent (309K vs. 29K occurrences).
my $DATA = <<'END_DATA';
n't	RB	not
's	VBZ	be
're	VBP	be
've	VBP	have
've	VB	have
'm	VBP	be
'll	MD	will
'd	MD	would
'd	VBD	have
wo	MD	will
ca	MD	can
END_DATA

if   ( $ARGV[0] =~ /^-[ad]$/ ) { print $DATA; }
else                           { die "Invalid usage: use option -a or -d\n"; }
