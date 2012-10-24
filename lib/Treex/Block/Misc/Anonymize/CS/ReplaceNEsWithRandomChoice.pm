package Treex::Block::Misc::Anonymize::CS::ReplaceNEsWithRandomChoice;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::Generation::CS;
my $generator = Treex::Tool::Lexicon::Generation::CS->new();

use utf8;

my $limit=20; # number of annonymization equivalents per a type-gender-number combination

# most frequent PDT named entities, given technical suffix, gender and number
my %frequent_names = (
    YFS => [qw( Hanna Marie Magdalena Jana Marta Hana Zuzana
                Martina Diana Věra Zora Anna Maryša Eva Ivana Helena Milada Vilma Jitka Petra)],
    YMS => [qw( Jan Karel Milan Václav Pavel Petr Zdeněk Vladimír
                Mike Luděk Ivan John Boris Rudolf Tomáš David Marián Michal Martin Bill)],
    SFS => [qw( Novotná Suková Navrátilová Habšudová Petrová Sanchezová Grafová
                Chadimová Nasrínová Pierceová Benešová Albrightová Vicariová Bhuttová
                Wiesnerová Čisťakovová Herrmannová Schmögnerová Kabanová Marvanová)],
    SMP => [qw( Němec Škvorecký Hood Jensen Dunka Forman Kuč Frankenstein Jíra Nedbálek
                Mrštík Kinský Lounský Nedvěd Hamádí Hersant Bokš Kapulet Mitrovský Gogh)],
    SMS => [qw( Novotný Clinton Chalupa Ježek Stráský Havel Mečiar Stalin Gorbačov Hlinka
                Vaculík Miloševič Dvořák Mandela Kuka Blažek Kohl Kovář Kotrba Rubáš)],
    GFP => [qw( Budějovice Pardubice Čechy Vítkovice Neratovice Drnovice Teplice Benátky Popovice
                Přešovice Košice Krkonoše Meadows Brémy Filipíny Domažlice Prachatice Malacky Alpy Slušovice)],
    GFS => [qw( Francie Kuba Afrika Libye Abcházie Asie Rwanda Čína Plzeň Británie Bratislava
                Bosna Praha Moskva Korea Arménie Itálie Evropa Amerika Hercegovina)],
    GIP => [qw( Vary Drážďany Bazaly Vodochody Kralupy Blšany Košťany Vysočany Golany Vinohrady
                Dukovany Lány Poděbrady Rokycany Klatovy Louny Špicberky Švýcary Paar Flandry)],
    GIS => [qw( Bělehrad Afghánistán Izrael Bohumín Vatikán Brod Zlín Temelín Irák Cheb Ázerbájdžán
                Frankfurt Kazachstán Detroit Mnichov Frýdek Vietnam Jablonec Vancouver Hradec)],
    GMS => [qw( Wallis Neumann Gyula Petrov Butrus Pavlov Warren Lom Powell Otomar Charlton Čihák
                Breda Murray Amos Mannheim Čabala Lubina Gilbert Jánský)],
    GNS => [qw( Německo Sarajevo Kladno Rusko Rumunsko Japonsko Norsko Československo Čečensko Brno
                Rakousko Irsko Řecko Polsko Finsko Slovensko Chorvatsko Španělsko Mexiko Turecko)],
);


my %cached_mapping;


sub _randomly_chosen_name {
    my ( $lemma_suffix, $gender, $number ) = @_;
}

sub process_nnode {
    my ( $self, $nnode ) = @_;

    return if $nnode->is_root;

    my $ne_type = $nnode->get_attr('ne_type');

    my $lemma_suffix;

    if ( $ne_type eq 'pf' ) {
        $lemma_suffix = 'Y';
    }
    elsif ( $ne_type eq 'ps' ) {
        $lemma_suffix = 'S';
    }
    elsif ( $ne_type =~ /^g/ ) {
        $lemma_suffix = 'G';
    }


    if ( $lemma_suffix ) {
        my @anodes = $nnode->get_anodes();
        if (@anodes != 1) {
            log_warn "exactly one corresponding node expected";
        }
        else {
            my $equiv_class = $lemma_suffix.substr($anodes[0]->tag,2,2);
            my $lemma = $anodes[0]->lemma;
            my $new_lemma;

            if ( $cached_mapping{$lemma}{$equiv_class} ) {
                $new_lemma = $cached_mapping{$lemma}{$equiv_class}
            }
            elsif (exists $frequent_names{$equiv_class}) {
                $new_lemma = $frequent_names{$equiv_class}->[int(rand($limit))];
                $cached_mapping{$lemma}{$equiv_class} = $new_lemma;
            }

            if ( $new_lemma ) {

                my ($new_form) = map { $_->get_form }
                    $generator->forms_of_lemma( $new_lemma, { tag_regex => $anodes[0]->tag } );

                if ( $new_form ) {
                    $anodes[0]->wild->{anonymized} = 1;
                    $anodes[0]->wild->{origform} = $anodes[0]->form;
                    $anodes[0]->set_lemma($new_lemma);
                    $anodes[0]->set_form($new_form);
                }
            }
        }
    }
}

binmode STDOUT,":utf8";
binmode STDIN,":utf8";
my %examples;

sub _extract_frequent_examples {
    while (<STDIN>) {
        chomp;
        s/^ +//;
        my ($number, $lemma, $tag) = split;
        next if $tag=~/^AU/;
        $lemma =~s/[_-].*?;([A-Z]).*// or next;
        my $netype = $1;
        my $gendernumber = substr($tag,2,2);
        next if $gendernumber =~ /X/;
        next if $lemma !~ /^\p{IsUpper}\p{IsLower}{2,}/;
        #        if (not exists $examples{$netype}{$gendernumber} or (keys %{$examples{$netype}{$gendernumber}})<20) {
        $examples{$netype}{$gendernumber}{$lemma}++;
        #        }
        #    print "$number $netype $gendernumber $lemma\n"
    }

    foreach my $ne_type (qw(Y S G)) {
        foreach my $gendernumber (sort keys %{$examples{$ne_type}}) {
            my @frequent_examples = #map {$examples{$ne_type}{$gendernumber}{$_}}
                sort {$examples{$ne_type}{$gendernumber}{$b}<=>$examples{$ne_type}{$gendernumber}{$a}}
                    keys %{$examples{$ne_type}{$gendernumber}};
            if (@frequent_examples >= $limit) {
                print " $ne_type$gendernumber => [qw( ".
                    (join " ",map {$_ #."-".$examples{$ne_type}{$gendernumber}{$_}
                               }
                         @frequent_examples[0..$limit-1]).")],\n";
            }
        }
    }
}


1;

#  ntred -il /net/projects/pdt/pdt20/data/filelists/5-a-all-train-bin.fl
#  ntred -TNe 'print $this->attr("m/lemma")."\t".$this->attr("m/tag")."\n";' | egrep '.;[A-Z]' | sort | uniq -c | sort -nr > sorted
#  cat sorted | perl -e 'use Treex::Block::Misc::Anonymize::CS::ReplaceNEsWithRandomChoice; Treex::Block::Misc::Anonymize::CS::ReplaceNEsWithRandomChoice::_extract_frequent_examples()'

=head1 NAME

Treex::Block::Misc::ReplacePersonalNamesCS

=head1 DESCRIPTION

Replace personal names (first names as well as surnames, signalled by lemma suffix)
by new names randomly chosen from the most frequent Czech names. Inflect the new names
accordingly to the morphological tag of original names.

=head1 AUTHOR

Zdeněk Žabokrtský

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
