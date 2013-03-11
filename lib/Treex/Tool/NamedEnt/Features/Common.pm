package Treex::Tool::NamedEnt::Features::Common;

use strict;
use warnings;

use Exporter qw/ import /;

my $common = [qw/ tag_features is_tabu_pos is_listed_entity/];
our %EXPORT_TAGS = (oneword => $common, twoword => $common, threeword => $common);

Exporter::export_ok_tags('oneword');
Exporter::export_ok_tags('twoword');
Exporter::export_ok_tags('threeword');


my %lists = ( months => {map {$_ => 1} qw/leden únor březen duben květen červen
					  červenec srpen září říjen listopad prosinec/ },
              cities => {},
              city_parts => {},
              streets => {},
              names => {},
              surnames => {},
              countries => {},
              objects => {map {$_ => 1} qw/Kč Sk USD zpráva mm ISDN/},
              institutions => {map {$_ => 1} qw/ODS EU OSN NATO Sparta Slavia Bohemians NHL/},
              clubs => { map {$_ => 1} qw /galerie kino škola organizace univerzita universita divadlo svaz
					   unie klub ministerstvo fakulta spolek sdružení orchestr organizace
					   union organization/}
	  );


my %tabu = map {$_ => 1} qw/D I J P V R T Z/;

my %tag_values = (pos => {map {$_ => 1} qw/A J T X N P V Z C D I R/},
                  subpos => {},
                  gender => {map {$_ => 1} qw/F T X N Y H - Z Q M I/},
                  number => {map {$_ => 1} qw/- S W D X P/},
                  case   => {map {$_ => 1} qw/6 X 3 7 2 - 1 4 5/}
              );


my @tag_categories = qw /pos subpos gender number case/;

sub tag_value_bitmap {
    my ($category, $value) = @_;

    my @bitmap = map {$value eq $_ ? 1 : 0} keys %{$tag_values{$category}};
    return @bitmap;
}


sub tag_features {
    my $tag = shift;
    my @tag_features;

    my @categories = split //, $tag;

    for my $catIndex (0, 2, 3, 4) {

        my $value = $categories[$catIndex];
        my $catName = $tag_categories[$catIndex];

        push @tag_features, tag_value_bitmap($catName, $value);
    }


    return @tag_features;
}


sub is_tabu_pos {
    my $pos = shift;

    return $tabu{$pos} ? 1 : 0;
}


sub is_listed_entity {
    my ($value, $list_name) = @_;

    return defined $lists{$list_name} and $lists{$list_name}{$value} ? 1 : 0;
}


1;
