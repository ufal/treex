#!/usr/bin/env perl

#Format is: singular plural
my $DATA = <<'END_DATA';
alga    algae
alumnus alumni
analysis	analyses
antenna	antennae
antithesis	antitheses
appendix	appendices
axis	axes
bacillus	bacilli
bacterium	bacteria
codex	codices
consortium   consortia
corpus	corpora
crisis	crises
criterion	criteria
curriculum	curricula
datum	data
diagnosis	diagnoses
dogma	dogmata
emphasis	emphases
focus	foci
formula	formulae
fungus	fungi
genus	genera
genie	genii
hypothesis	hypotheses
index	indices
larva	larvae
lemma	lemmata
matrix	matrices
memorandum	memoranda
millennium  millennia
nucleus	nuclei
papilla	papillae
parenthesis	parentheses
phenomenon	phenomena
pneumococcus	pneumococci
pupa	pupae
pylorus	pylori
schema	schemata
spectrum	spectra
stigma	stigmata
stimulus		stimuli
staphylococcus	staphylococci
stratum	strata
streptococcus	streptococci
tempo	tempi
thesaurus	thesauri
thesis	theses
virtuoso	virtuosi
vita	vitae
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
        print "$line\n";
    }
    return;
}

if    ( $ARGV[0] eq '-a' ) { analyze(); }
elsif ( $ARGV[0] eq '-g' ) { generate(); }
elsif ( $ARGV[0] eq '-d' ) { print $DATA; }
else                       { die "Invalid usage: use option -a, -g or -d\n"; }
