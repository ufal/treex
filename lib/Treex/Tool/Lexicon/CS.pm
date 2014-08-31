package Treex::Tool::Lexicon::CS;

use strict;
use warnings;
use Treex::Core::Common;
use utf8;
use autodie;

use Treex::Core::Resource qw(require_file_from_share);

#TODO: Better way how to make it automatically download.
my $POSSADJ_FN = 'data/models/lexicon/cs/possessive_adjectives.tsv';

my $possadj_filename = require_file_from_share( $POSSADJ_FN, 'Lexicon::CS' );

my @DICENDI_VERBS =
    qw(dodat dodávat doplnit hlásit hodnotit informovat komentovat konstatovat líčit
    litovat mínit napsat ohlásit ohlašovat oznámit oznamovat podotknout popisovat popsat potvrdit povědět
    poznamenat připomenout přiznat přiznávat prohlásit prohlašovat psát reagovat
    říci říkat sdělit soudit svěřit_se tvrdit upozornit upozorňovat upřesnit upřesňovat usoudit
    uvádět uvést uzavřít uznat uznávat vylíčit vypravovat vyprávět vysvětlit vysvětlovat
    vyzvat vyzývat vzpomínat zdůraznit);
my %IS_DICENDI_VERB;

foreach my $lemma (@DICENDI_VERBS) {
    $IS_DICENDI_VERB{$lemma} = 1;
}

sub is_dicendi_verb {
    my ($t_lemma) = @_;
    return $IS_DICENDI_VERB{$t_lemma};
}

my %NUMBER_FOR_NUMERAL = (
    'nula'=>0, 'jedna'=>1, 'jeden'=>1, 'dva'=>2, 'tři'=>3, 'čtyři'=>4, 'pět'=>5,
    'šest'=>6, 'sedm'=>7, 'osm'=>8, 'devět'=>9, 'deset'=>10,
    'jedenáct'=>11, 'dvanáct'=>12, 'třináct'=>13, 'čtrnáct'=>14, 'patnáct'=>15,
    'šestnáct'=>16, 'sedmnáct'=>17, 'osmnáct'=>18, 'devatenáct'=>19,
    'dvacet'=>20, 'třicet'=>30, 'čtyřicet'=>40, 'padesát'=>50,
    'šedesát'=>60, 'sedmdesát'=>70, 'osmdesát'=>80, 'devadesát'=>90,
    'sto'=>100, 'tisíc'=>1_000, 'milión'=>1_000_000, 'milion'=>1_000_000, 'miliarda'=>1_000_000_000,

    # fractions
    'půl'=>1/2, 'polovina'=>1/2, 'třetina'=> 1/3, 'čtvrt'=>1/4, 'čtvrtina' => 1/4,
    'pětina'=>1/5, 'šestina'=>1/6, 'sedmina'=>1/7, 'osmina'=>1/8, 'devítina' => 1/9,
    'desetina' => 1/10, 'jedenáctina' => 1/11, 'dvanáctina' => 1/12, 'třináctina' => 1/13,
    'čtrnáctina' => 1/14, 'patnáctina' => 1/15, 'šestnáctina' => 1/16, 'sedmnáctina' => 1/17,
    'osmnáctina' => 1/18, 'devatenáctina' => 1/19, 'dvacetina' => 1/20,
    'třicetina' => 1/30, 'čtyřicetina' => 1/40, 'padesátina' => 1/50, 'šedesátina' => 1/60,
    'sedmdesátina' => 1/70, 'osmdesátina' => 1/80, 'devadesátina' => 1/90,
    'setina' => 1/100, 'tisícina' => 1/1_000, 'milióntina' => 1/1_000_000, 'miliontina'=>1/1_000_000,

    # other
    'tucet'=>12, 'kopa'=>60, 'veletucet'=>144,
    );

my %NUMERAL_FOR_NUMBER = (
    0=>'nula', 1=>'jedna', 2=>'dva', 3=>'tři', 4=>'čtyři', 5=>'pět', 6=>'šest', 7=>'sedm',
    8=>'osm', 9=>'devět', 10=>'deset', 11=>'jedenáct', 12=>'dvanáct', 13=>'třináct',
    14=>'čtrnáct', 15=>'patnáct', 16=>'šestnáct', 17=>'sedmnáct', 18=>'osmnáct',
    19=>'devatenáct', 20=>'dvacet', 30=>'třicet', 40=>'čtyřicet', 50=>'padesát', 60=>'šedesát',
    70=>'sedmdesát', 80=>'osmdesát', 90=>'devadesát', 100=>'sto', 1000=>'tisíc',
);

sub number_for {
    my ($lemma) = @_;
    return $lemma if $lemma =~ /^\d+$/;
    return $NUMBER_FOR_NUMERAL{$lemma};
}


# 5 -> pěti, 19 -> devatenácti, 65 -> pětašedesáti
sub numeral_prefix_for_number {
    my $number = shift;
    return $number if $number =~ /^0/;
    return 'jedno' if $number == 1;
    return 'dvou' if $number == 2;
    return 'tří' if $number == 3;
    return 'čtyř' if $number == 4;
    return 'devíti' if $number == 9;
    return 'sto' if $number == 100;
    return $NUMERAL_FOR_NUMBER{$number}.'i' if $NUMERAL_FOR_NUMBER{$number};
    if ( $number =~ /^(\d)(\d)$/ ) {
        return $NUMERAL_FOR_NUMBER{$2}.'a'.$NUMERAL_FOR_NUMBER{$1.'0'}.'i' if $2 != 1;
        return 'jedna'.$NUMERAL_FOR_NUMBER{$1.'0'}.'i';
    }
    return $number;
}

my %NUMBER_OF_MONTH = (
    'leden'=>1,    'únor'=>2,  'březen'=>3, 'duben'=>4,  'květen'=>5,    'červen'=>6,
    'červenec'=>7, 'srpen'=>8, 'září'=>9,   'říjen'=>10, 'listopad'=>11, 'prosinec'=>12,
);

sub number_of_month {
    my ($lemma) = @_;
    log_fatal('uninitialized lemma in Treex::Tool::Lexicon::CS::number_of_month') if !defined $lemma;
    return $NUMBER_OF_MONTH{$lemma};
}

my %NUMBER_OF_DAY = (
    'pondělí' => 1, 'úterý' => 2, 'středa' => 3, 'čtvrtek' => 4,
    'pátek' => 5, 'sobota' => 6, 'neděle' => 7,
);

sub number_of_day {
    my ($lemma) = @_;
    return $NUMBER_OF_DAY{$lemma};
}

my %IS_PLURAL_TANTUM;
my @PL_TANTUM_NOUNS = qw(alpy brýle čechy doksy drážďany dveře finance hodinky
 housle hrábě hradčany jatka jatky játra kalhoty kleště křtiny kvasnice lázně námluvy
 narozeniny nebesa noviny nůžky pardubice peníze plavky povidla příušnice sáně
 sáňky spalničky tatry tepláky teplice trenýrky ústa vánoce velikonoce vidle
 záda zarděnky zásnuby žně);
foreach my $lemma (@PL_TANTUM_NOUNS ) {
    $IS_PLURAL_TANTUM{$lemma} = 1;
}

sub is_plural_tantum {
    my ($lemma) = @_;
    return $IS_PLURAL_TANTUM{lc $lemma};
}

my %noun2possadjective;
open my $A, '<:utf8', $possadj_filename;
while (<$A>) {
    chomp;
    next if /##/;
    my ($adj_lemma_long, $count) = split /\t/;
    if (defined $count and $count >= 2 and $adj_lemma_long =~ /^([^_]+)_.*\/(\(.+\)\_)?\((\^UV)?\*(\d+)(.*)\)/) {
        my ($adj_short, $chars_to_delete, $new_suffix) = ($1, $4, $5);
        my $noun = $adj_short;
        $noun = substr($noun, 0, length($noun) - $chars_to_delete) . $new_suffix;
        $adj_short =~ s/-.+//;
        $noun =~ s/-.+//;
        $noun2possadjective{$noun} = $adj_short;
    }
}
close $A;

sub get_poss_adj {
    my ($noun_lemma) = @_;
    # fallback - case changes
    if ( !$noun2possadjective{$noun_lemma} ){
        if ( $noun_lemma =~ /^\p{Lu}/ ){     # try lowercasing uppercase lemma
            return $noun2possadjective{ lcfirst( $noun_lemma ) };
        }
        elsif ( $noun_lemma =~ /^\p{Ll}/ ) { # try uppercasing lowercase lemma
            return $noun2possadjective{ ucfirst( $noun_lemma ) };
        }
    }
    return $noun2possadjective{$noun_lemma};
}

# This truncates Czech morphological lemmas, leaving out the explanatory part.
# If the second parameter is set to true, the number for homonymous lemmas is truncated as well.
# See http://ufal.mff.cuni.cz/pdt2.0/doc/manuals/en/m-layer/html/ch02s01.html
sub truncate_lemma {
    my ($lemma, $strip_numbers) = @_;    
    
    $lemma =~ s/((?:(`|_;|_:|_,|_\^|))+)(`|_;|_:|_,|_\^).+$/$1/;

    # Lemma cannot be empty (e.g. "`a la" instead of "à la" in ČNK)
    if ($lemma eq ''){
        $lemma = $_[0];
    }
    if ($strip_numbers){
        $lemma =~ s/(.+)-[0-9].*$/$1/;
    }
    return $lemma;
}

# Given a lemma, this returns all the term types (given name - Y, surname - S, geography - G etc.) this lemma belongs to
sub get_term_types {
    
    my ($lemma) = @_;
    my $term_types = '';
    
    while ( $lemma =~ m/_;([YSEGKRmHULjgcybuwpzo])/g ){
        $term_types .= $1;
    }
    return $term_types;
}


# Returns true if the given lemma belongs to a modal verb
sub is_modal_verb {
    my ($lemma) = @_;
    return $lemma =~ m/^(mus[ei]t|mít|chtít|hodlat|moci|dát|smět|dovést|umět)(_|$)/;
}


1;

__END__

=encoding utf8

=head1 NAME

Treex::Tool::Lexicon::CS

=head1 SYNOPSIS

use Treex::Tool::Lexicon::CS;

if ( Treex::Tool::Lexicon::CS::is_dicendi_verb('říci')) {
    print "OK\n";
}

print Treex::Tool::Lexicon::CS::number_for('sedm'); # prints 7

print Treex::Tool::Lexicon::CS::truncate_lemma('jak-1_;L_^(živočich)'); # prints jak-1
print Treex::Tool::Lexicon::CS::truncate_lemma('jak-1_;L_^(živočich)', 1); # prints jak

if ( Treex::Tool::Lexicon::CS::is_modal_verb('muset')){
    print "OK\n";
}

print Treex::Tool::Lexicon::CS::get_term_types('jak-1_;L_^(živočich)'); # prints L

=head1 DESCRIPTION

This module should include support for miscellaneous queries
involving Czech lexicon and morphology.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2009-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
