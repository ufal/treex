package Treex::Block::Misc::Anonymize::CS::ReplaceNEsWithRandomChoice;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'language'     => ( is => 'rw', isa => 'Str', default  => 'en' );

use Treex::Tool::Lexicon::Generation::CS;
my $generator = Treex::Tool::Lexicon::Generation::CS->new();

use utf8;

# most frequent PDT named entities, given technical suffix, gender and number
my %frequent_names = (
    YFS => [qw( Hanna Marie Magdalena Jana Marta Hana Zuzana Martina Diana Věra Zora Anna Maryša Eva Ivana Helena Milada Vilma Jitka Petra)],
    YMS => [qw( Jan Karel Milan Václav Pavel Petr Zdeněk Vladimír Mike Luděk Ivan John Boris Rudolf Tomáš David Marián Michal Martin Bill)],
    SFS => [qw( Novotná Suková Navrátilová Habšudová Petrová Sanchezová Grafová Chadimová Nasrínová Pierceová Benešová Albrightová Vicariová Bhuttová Wiesnerová Čisťakovová Herrmannová Schmögnerová Kabanová Marvanová)],
    SMP => [qw( Němec Škvorecký Hood Jensen Dunka Forman Kuč Frankenstein Jíra Nedbálek Mrštík Kinský Lounský Nedvěd Hamádí Hersant Bokš Kapulet Mitrovský Gogh)],
    SMS => [qw( Novotný Clinton Chalupa Ježek Stráský Havel Mečiar Stalin Gorbačov Hlinka Vaculík Miloševič Dvořák Mandela Kuka Blažek Kohl Kovář Kotrba Rubáš)],
    GFP => [qw( Budějovice Pardubice Čechy Vítkovice Neratovice Drnovice Teplice Benátky Popovice Přešovice Košice Krkonoše Meadows Brémy Filipíny Domažlice Prachatice Malacky Alpy Slušovice)],
    GFS => [qw( Francie Kuba Afrika Libye Abcházie Asie Rwanda Čína Plzeň Británie Bratislava Bosna Praha Moskva Korea Arménie Itálie Evropa Amerika Hercegovina)],
    GIP => [qw( Vary Drážďany Bazaly Vodochody Kralupy Blšany Košťany Vysočany Golany Vinohrady Dukovany Lány Poděbrady Rokycany Klatovy Louny Špicberky Švýcary Paar Flandry)],
    GIS => [qw( Bělehrad Afghánistán Izrael Bohumín Vatikán Brod Zlín Temelín Irák Cheb Ázerbájdžán Frankfurt Kazachstán Detroit Mnichov Frýdek Vietnam Jablonec Vancouver Hradec)],
    GMS => [qw( Wallis Neumann Gyula Petrov Butrus Pavlov Warren Lom Powell Otomar Charlton Čihák Breda Murray Amos Mannheim Čabala Lubina Gilbert Jánský)],
    GNS => [qw( Německo Sarajevo Kladno Rusko Rumunsko Japonsko Norsko Československo Čečensko Brno Rakousko Irsko Řecko Polsko Finsko Slovensko Chorvatsko Španělsko Mexiko Turecko)],
);


my %mapping;

sub process_anode {
    my ( $self, $anode ) = @_;

    return if $anode->is_root;

    if ($anode->lemma =~ /;([YS])/) {
        my $lemma = $anode->lemma;
        my $type = $1;

        my $new_lemma = $mapping{$type}{$lemma};

        if (not defined $new_lemma) {
            my $rand_index = rand(scalar(@{$frequent_names{$type}}));
            $new_lemma = $frequent_names{$type}[$rand_index];
            $mapping{$type}{$lemma} = $new_lemma;
        }

        $anode->set_lemma($new_lemma);
        my ($new_form) = map {$_->get_form}
            $generator->forms_of_lemma( $new_lemma, { tag_regex => $anode->tag } );
        $anode->set_form($new_form);

    }
}

binmode STDOUT,":utf8";
binmode STDIN,":utf8";
my %examples;
my $limit=20;
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
