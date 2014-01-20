package Treex::Tool::Lexicon::EN::Hypernyms;
use utf8;
use strict;
use warnings;
use autodie;
use Treex::Core::Resource qw(require_file_from_share);

my $DATA_FILE = 'data/models/lexicon/en/hypernyms.tsv';
my $file_path = require_file_from_share( $DATA_FILE, 'Treex::Tool::Lexicon::EN::Hypernyms' );

my %WATER_BODIES;
my %MEALS;
my %ISLANDS;
my %MOUNTAIN_PEAKS;
my %MOUNTAIN_CHAINS;
my %COUNTRIES;
my %NATIONS;

open my $F, '<:encoding(utf8)', $file_path;
while (<$F>) {
    chomp;
    my ( $lemma, $hypernyms ) = split /\t/, $_;
    if ( $hypernyms =~ /\b(meal)\b/ ) {
        $MEALS{$lemma} = 1;
    }
    if ( $hypernyms =~ /\b(ocean|sea|river)\b/ ) {
        $WATER_BODIES{$lemma} = 1;
    }
    if ( $hypernyms =~ /\b(island)\b/ ) {
        $ISLANDS{$lemma} = 1;
    }
    if ( $hypernyms =~ /\b(mountain peak)\b/ ) {
        $MOUNTAIN_PEAKS{$lemma} = 1;
    }
    if ( $hypernyms =~ /\b(chain of mountains)\b/ ) {
        $MOUNTAIN_CHAINS{$lemma} = 1;
    }
    if ( $hypernyms =~ /\b(country|kingdom|state|county)\b/ ) {
        $COUNTRIES{$lemma} = 1;
    }
    if ( $hypernyms =~ /\b(nation)\b/ ) {
        $NATIONS{$lemma} = 1;
    }
}
close $F;

sub is_water_body {
    return $WATER_BODIES{lc $_[0]} // 0;
}

sub is_meal {
    return $MEALS{lc $_[0]} // 0;
}

sub is_island {
    return $ISLANDS{lc $_[0]} // 0;
}

sub is_mountain_peak {
    return $MOUNTAIN_PEAKS{lc $_[0]} // 0;
}

sub is_mountain_chain {
    return $MOUNTAIN_CHAINS{lc $_[0]} // 0;
}

sub is_country {
    return $COUNTRIES{lc $_[0]} // 0;
}

sub is_nation {
    return $NATIONS{lc $_[0]} // 0;
}

1;

__END__

=encoding utf8

=head1 NAME

Treex::Tool::Lexicon::EN::Hypernyms

=head1 SYNOPSIS

 use Treex::Tool::Lexicon::EN::Hypernyms;
 print Treex::Tool::Lexicon::EN::PersonalRoles::is_water_body('Atlantic');
 # prints 1

=head1 DESCRIPTION

Functions testing if a lemma belongs to a given set of objects (water bodies, meals, islands,
countries... etc.).

The membership is based on WordNet.

=head1 AUTHOR

Ondřej Dušek <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

