package Treex::Block::Filter::CzEng::InconsistentNumeral;
use Moose;
use Treex::Core::Common;
use Treex::Core::Log;
extends 'Treex::Block::Filter::CzEng::Common';

my %alternatives = (
    1 => ["jedn","jeden","prvn","13"],
    2 => ["dva","druh","dvě","dvou","14"],
    3 => ["tři","třetí","třech","tří","troj","15"],
    4 => ["čtyř","čtvrt","16"],
    5 => ["pět","pát","17"],
    6 => ["šest","18"],
    7 => ["sedm","19"],
    8 => ["osm","20"],
    9 => ["devět","devát","21"],
    10 => ["deset","desát","desít","22"],
    11 => ["jedenáct","23"],
    12 => ["dvanáct","24"],
    13 => ["třináct"],
    14 => ["čtrnáct"],
    15 => ["patnáct"],
    16 => ["šestnáct"],
    17 => ["sedmnáct"],
    18 => ["osmnáct"],
    19 => ["devatenáct"],
    20 => ["dvacet","dvacát","dvacít"],
    24 => ["dvacet čtyři","dvacetčtyři"],
    25 => ["dvacet pět","pětadvac"],
    27 => ["dvacetsedm","dvacetisedm","dvacátýsedm","dvacátásedm","dvacátésedm"],
    30 => ["třicet","třicát"],
    40 => ["čtyřicet","čtyřicát"],
    50 => ["padesát"],
    60 => ["šedesát"],
    70 => ["sedmdesát"],
    80 => ["osmdesát"],
    90 => ["devadesát"],
    100 => ["sto","stý","stá","sté"],
    1000 => ["tisíc"],
    1920 => ["20","dvacát"],
    1930 => ["30","třicát"],
    1940 => ["40","čtyřic"],
    1950 => ["50","padesát"],
    1960 => ["60","šedesát"],
    1970 => ["70","sedmdesát"],
    1980 => ["80","osmdesát"],
    1990 => ["90","devadesát"],
    2001 => ["01"],
    2002 => ["02"],
    2003 => ["03"],
    2004 => ["04"],
    2005 => ["05"],
    2006 => ["06"],
    2007 => ["07"],
    2008 => ["08"],
    2009 => ["09"]
    );

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $en      = $bundle->get_zone('en')->sentence;
    my $cs      = $bundle->get_zone('cs')->sentence;
    
    my $wrong = 0;

    my @numbers;
    push @numbers, $1 while $en =~ m/(\d+)/g;

    my @missing = grep {      
        my $pattern = $_;
        $pattern .= "|" . join("|", @{ $alternatives{$_}}) if defined $alternatives{$_};
        $cs !~ m/$pattern/;
    } @numbers;

    if (@missing) {
        # equivalent to containSameNumerals method in the original filter
        $wrong = grep { ($cs =~ m/$_/ && $en !~ m/$_/) || ($cs !~ m/$_/ && $en =~ m/$_/) } (0 .. 9);
    }

    $self->add_feature( $bundle, 'inconsistent_numeral' ) if $wrong;

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::InconsistentNumeral

English side contains a numeral not confirmed by the Czech side.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky, Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
