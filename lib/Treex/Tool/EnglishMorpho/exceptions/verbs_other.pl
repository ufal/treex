#!/usr/bin/env perl
my $DATA = <<'END_DATA';
am	VBP	be
are	VBP	be
is	VBZ	be
has	VBZ	have
hath	VBZ	have
being	VBG	be
belied	VBN	belie
belied	VBD	belie
belies	VBZ	belie
belying	VBG	belie
underlies	VBZ	underlie
underlied	VBD	underlie
underlied	VBN	underlie
underlying	VBG	underlie
ageing	VBG	age
skiing	VBG	ski
END_DATA

if   ( $ARGV[0] =~ /^-[ad]$/ ) { print $DATA; }
else                           { die "Invalid usage: use option -a or -d\n"; }
