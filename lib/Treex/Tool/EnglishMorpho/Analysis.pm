package Treex::Tool::EnglishMorpho::Analysis;

use strict;
use warnings;
use Treex::Core::Log;
use Treex::Core::Resource qw(require_file_from_share);

# --------- initialization ---------

my ( %muj_slovnik, %big_slovnik, %past_slovesa, %partic_slovesa, );
my $data_directory = 'data/models/morpho_analysis/en';
log_info("Loading English morphology tables from $data_directory ...\n");
_load_dictionary( require_file_from_share("$data_directory/muj_slovnik.txt"), \%muj_slovnik );
_load_dictionary( require_file_from_share("$data_directory/big_slovnik.txt"), \%big_slovnik );
_load_list( require_file_from_share("$data_directory/preterite.tsv"),  \%past_slovesa );
_load_list( require_file_from_share("$data_directory/participle.tsv"), \%partic_slovesa );
log_info("Loaded.\n");

# --------- interface ---------

sub Get_possible_tags ($) {
    my $wordform  = shift;
    my $lowerform = lc($wordform);

    my $radek = "";

    if ( exists $muj_slovnik{$lowerform} ) {
        foreach my $tag ( keys %{ $muj_slovnik{$lowerform} } ) {
            $radek = $radek . " " . $tag;
        }
        if ( $lowerform ne $wordform ) {
            $radek = $radek . " NNP";
        }
    }
    else {    # neni ve slovniku uzavrenych trid
        if ( exists $big_slovnik{$lowerform} ) {
            foreach my $tag ( keys %{ $big_slovnik{$lowerform} } ) {
                $radek = $radek . " " . $tag;
            }
            if ( $lowerform ne $wordform ) {
                $radek = $radek . " NNP NNPS";
            }
        }
        else {
            $radek = $radek . " FW JJ NN NNS RB";

            if (( $lowerform =~ /er$/ )
                or ( $lowerform =~ /er-/ )
                or
                ( $lowerform =~ /more-/ ) or ( $lowerform =~ /less-/ )
                )
            {
                $radek = $radek . " JJR RBR";
            }    # comparative
            if (( $lowerform =~ /est$/ )
                or ( $lowerform =~ /est-/ )
                or
                ( $lowerform =~ /most-/ ) or ( $lowerform =~ /least-/ )
                )
            {
                $radek = $radek . " JJS RBS";
            }    # superlative
            if ( ( $lowerform =~ /ing$/ ) or ( $lowerform =~ /[^aeiouy]in$/ ) ) {
                $radek = $radek . " VBG";
            }
            if ( $lowerform =~ /[^s]s$/ ) {
                $radek = $radek . " VBZ";
            }    # 3. os
            else {
                $radek = $radek . " VB VBP";
            }    # non-3. os

            if ( $lowerform ne $wordform ) {
                $radek = $radek . " NNP NNPS";
            }
            elsif ( $lowerform =~ /^[0-9']/ ) {
                $radek = $radek . " NNP";
            }
            if (( $lowerform =~ /[^a-zA-Z0-9]+/ )
                or
                ( $lowerform =~ /^&.*;$/ )
                )
            {
                $radek = $radek . " SYM";
            }
            if ( ( $lowerform =~ /[-0-9]+/ ) or ( $lowerform =~ /^[ixvcmd\.]+$/ ) ) {
                $radek = $radek . " CD";
            }
        }
        if ( exists $past_slovesa{$lowerform} ) {
            $radek = $radek . " VBD";
        }
        if ( exists $partic_slovesa{$lowerform} ) {
            $radek = $radek . " VBN";
        }
        if ( $lowerform =~ /ed$/ ) {
            $radek = $radek . " VBD VBN";
        }
    }

    $radek =~ s/^ //;
    return ( split / /, $radek );
}

sub _load_dictionary {
    my ( $soubor, $slovnik ) = @_;
    my ( $radek, $slovo, @items, $tag );

    open( DATA, $soubor ) or die "Can't open morphology file $soubor.";
    while ( $radek = <DATA> ) {
        chomp($radek);
        if ( $radek eq '' ) {
            next;
        }
        @items = split( qr/ /, $radek );
        $slovo = shift(@items);
        $slovo = lc($slovo);
        while ( scalar(@items) > 0 ) {
            $tag = shift(@items);
            $slovnik->{$slovo}->{$tag} = 1;
        }
    }
    close(DATA);
}

sub _load_list {
    my ( $soubor, $slovnik ) = @_;
    open DATA, $soubor or die "Can't open morphology file $soubor.";
    while (<DATA>) {
        chomp;
        $slovnik->{$_} = 1;
    }
    close(DATA);
}

1;

=head1 NAME

Treex::Tool::EnglishMorpho::Analysis


=head1 SYNOPSIS

 use Treex::Tool::EnglishMorpho::Analysis;

 foreach my $wordform (qw(John loves the yellow ball of his sister .)) {
   my @tags = Treex::Tool::EnglishMorpho::Analysis::Get_possible_tags($wordform);
   print "$wordform -> @tags\n";
 }



=head1 DESCRIPTION

Function Get_possible_tags($wordform) returns the list of PennTreebank-style
morphological tags for the given word form.

=head1 AUTHORS

Johanka Drahomíra Doležalová

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Tomáš Kraut <kraut@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


