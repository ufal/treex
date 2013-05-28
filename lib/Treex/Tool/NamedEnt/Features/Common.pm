package Treex::Tool::NamedEnt::Features::Common;

use strict;
use warnings;

use Treex::Core::Common;
use Treex::Core::Resource 'require_file_from_share';

use Exporter qw/ import /;

my $common = [qw/ tag_features is_tabu_pos is_listed_entity get_built_list_names is_year_number is_month_number is_day_number/];

my $tests = [qw/ tag_value_bitmap tag_features is_tabu_pos is_listed_entity get_class_number get_class_from_number get_built_list_names is_year_number is_month_number is_day_number/];

our %EXPORT_TAGS = (oneword => $common, twoword => $common, threeword => $common, tests => $tests);
our @EXPORT_OK = qw/get_class_number get_class_from_number $FALLBACK_LEMMA $FALLBACK_TAG/;

our $FALLBACK_LEMMA = ".";
our $FALLBACK_TAG   = "Z:-------------";

Exporter::export_ok_tags('oneword');
Exporter::export_ok_tags('twoword');
Exporter::export_ok_tags('threeword');
Exporter::export_ok_tags('tests');

my @classes = qw/a ah at az
                 c cb cn cp cr cs
                 g gc gh gl gp gq gr gs gt gu g_
                 i ia ic if io i_
                 m mi mn mr mt
                 n na nc ni nm np nq nr nw n_
                 o oa oc oe om op or o_
                 p pb pc pd pf pm pp ps p_
                 q qc qo
                 t tc td tf th tm tn tp ts ty

                 lower segm upper cap s f ?

                 sf ti m_ qu gy/; # todo tenhle posledni radek jsou veci, ktery nejsou v techreportu. 

my @containers = qw/P T A C I/;

#I jako slozena instituce je vicemene legalni, ale je tam jen jednou
# sf na radce 4155 je spatne taglý (má tam bejt jen s)
# ti je zřejmě použito pro interval: <ti 27 . 5 . - 3 . 6 .> ale "Od <ti 2.kvetna do 4.cervna>" je podivny
# m_ je použito pro tiskový agentury - to by mělo bejt nahrazeno mn.
# qu má bejt gu. (v Popradu)
# gy má bejt ty. (roku 1922)

# jednopísmenkový entity tam jsou jen chybou. - dá se taky vyčistit
# otázkou zůstává, zda použít i ty rozšířený - neoznačují entity, ale lze je použít k trénování.

my %classNumbers = map {$classes[$_] => $_} 0 .. $#classes;

my %lists = ( months => {map {$_ => 1} qw/leden únor březen duben květen červen
					  červenec srpen září říjen listopad prosinec/ },
              cities => {},
              city_parts => {},
              streets => {},
              first_names => {},
              surnames => {},
              countries => {},
              objects => {map {$_ => 1} qw/Kč Sk USD zpráva mm ISDN/},
              institutions => {map {$_ => 1} qw/ODS EU OSN NATO Sparta Slavia Bohemians NHL/},
              clubs => { map {$_ => 1} qw /galerie kino škola organizace univerzita universita divadlo svaz
					   unie klub ministerstvo fakulta spolek sdružení orchestr organizace
					   union organization/}
	  );

log_info('Retrieving NE lists');

for my $share_list (qw /cities city_parts first_names surnames countries streets/) {
    my $filename = "data/models/sysnerv/cs/" . $share_list . ".txt";

    my $file = require_file_from_share($filename, 'Treex::Tool::NamedEnt::Features::Common');

    open LISTFILE, $file or log_error('Cannot retrieve list file $filename') and next;

    chomp(my @list = <LISTFILE>);

    close LISTFILE;

    $lists{$share_list} = {map {$_ => 1} @list};
}


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

    return (defined $lists{$list_name} and $lists{$list_name}{$value}) ? 1 : 0;
}

sub get_class_number {
    my $class = shift;
    return $classNumbers{$class};
}


sub get_class_from_number {
    my $n = shift;
    return $classes[$n];
}


sub get_built_list_names {
    return keys %lists;
}

sub is_year_number {
    my $token = shift;
    return ($token =~ /^[12][[:digit:]][[:digit:]][[:digit:]]$/ ) ? 1 : 0;
}


sub is_month_number {
    my $token = shift;
    return ($token =~ /^[1-9]$/ || $token =~ /^1[012]$/) ? 1 : 0;
}

sub is_day_number {
    my $token = shift;
    return ($token =~ /^[1-9]$/ || $token =~ /^[12][[:digit:]]$/ || $token =~ /^3[01]$/ ) ? 1 : 0;
}

1;
