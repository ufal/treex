#!/usr/bin/env perl
my $DATA = <<'END_DATA';
basis	bases
brother	brothers	#1 regular
brother	brethen	#2
calf	calves
elf	elves
fig.	figs.
foot	feet
goose	geese
grandchild	grandchildren
grouse	grouse
half	halves
hoof	hoofs	#1 regular
hoof	hooves	#2
child	children
knife	knives
leaf	leaves
life	lives
loaf	loaves
louse	lice
man men
money	monies
moose   moose
mouse	mice
no.	nos.
ox	oxen
passer-by	passers-by
penny	pence
runner-up	runners-up
scarf	scarfs	#1 regular
scarf	scarves	#2
self	selves
sheaf	sheaves
shelf	shelves
thief	thieves
tooth	teeth
wife	wives
wolf	wolves
woman women
bureau	bureaux
kubbitz	kibbutzim
lira	lire
END_DATA

sub analyze() {
    foreach my $line ( split( "\n", $DATA ) ) {
        next if $line =~ /regular$/;
        my ( $singular, $plural ) = split( /\s+/, $line );
        print "$plural\tNNS\t$singular\n";
    }
    return;
}

sub generate() {
    foreach my $line ( split( "\n", $DATA ) ) {
        next if $line =~ /regular$/;
        next if $line =~ /#2$/;
        print "$line\n";
    }
    return;
}

if    ( $ARGV[0] eq '-a' ) { analyze(); }
elsif ( $ARGV[0] eq '-g' ) { generate(); }
elsif ( $ARGV[0] eq '-d' ) { print $DATA; }
else                       { die "Invalid usage: use option -a, -g or -d\n"; }
