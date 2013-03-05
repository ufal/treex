package Treex::Tool::NamedEnt::Features;

use strict;
use warnings;

use Data::Dumper;

use Exporter;
use base 'Exporter';
our @EXPORT = qw / extract_oneword_features str2int int2str /

#str2int int2str extract_twoword_features 
#                  extract_threeword_features 
#                  $SVM_MODEL_DIR $FALLBACK_LEMMA $FALLBACK_TAG %CLASSES 
#                  $ONEWORD_MODEL_FILENAME $TWOWORD_MODEL_FILENAME %TABU_TAGS
#                  $THREEWORD_MODEL_FILENAME %CONTAINERS);


#vezme file ve formatu tmt a naparsuje ho
sub load_tmt {
    my $file = shift;

    my $doc = Treex::Core::Document->new( {filename => $file} );
    my @bundles = $doc->getBundles();


    for my $bundle (@bundles) {

	

    }


}


# vezme file ve formatu form/lemma/tag
sub load_plain {




}



sub extract_features {


}1


























#####################
# Private Constants #
#####################

my %MORPH_TAGS = (
    'pos' => {
        'A' => 1,
        'J' => 1,
        'T' => 1,
        'X' => 1,
        'N' => 1,
        'P' => 1,
        'V' => 1, 'Z' => 1, 'C' => 1, 'D' => 1, 'I' => 1, 'R' => 1,
    },
    'gender' => {
        'F' => 1,
        'T' => 1,
        'X' => 1,
        'N' => 1,
        'Y' => 1,
        'H' => 1,
        '-' => 1, 'Z' => 1, 'Q' => 1, 'M' => 1, 'I' => 1,
    },
    'number' => {
        '-' => 1,
        'S' => 1,
        'W' => 1,
        'D' => 1,
        'X' => 1,
        'P' => 1,
    },
    'case' => {
        "6" => 1,
        "X" => 1,
        "3" => 1,
        "7" => 1,
        "2" => 1,
        "-" => 1, "1" => 1, "4" => 1, "5" => 1,
    },
);

my %MORPH_TAG_NUMBERS = (
    'pos'    => 0,
    'gender' => 2,
    'number' => 3,
    'case'   => 4,
);

my %MONTHS = (
    'leden'  => 1, 'únor'   => 1, 'březen'   => 1, 'duben'    => 1,
    'květen' => 1, 'červen' => 1, 'červenec' => 1, 'srpen'    => 1,
    'září'   => 1, 'říjen'  => 1, 'listopad' => 1, 'prosinec' => 1,
);

my %CITIES;
my %CITY_PARTS;
my %STREETS;
my %NAMES;
my %SURNAMES;
my %COUNTRIES;
my %OBJECTS = (
    'Kč'     => 1,
    'Sk'     => 1,
    'USD'    => 1,
    'zpráva' => 1,
    'mm'     => 1,
    'ISDN'   => 1,
);

my %INSTITUTIONS = (
    'ODS' => 1, 'EU' => 1, 'OSN' => 1, 'NATO' => 1, 'Sparta' => 1, 'Slavia' => 1, 'NHL' => 1,
);

my %CLUBS = (
    'galerie' => 1, 'kino' => 1, 'škola' => 1, 'organizace' => 1, 'univerzita' => 1,
    'universita' => 1, 'divadlo' => 1, 'svaz' => 1, 'unie' => 1, 'klub' => 1, 
    'ministerstvo' => 1, 'fakulta' => 1, 'spolek' => 1, 'sdružení' => 1,
    'orchestr' => 1, 'organizace' => 1, 'union' => 1, 'organization' => 1,
);


# Transform cathegorical value of morphologic tag to binary vector
sub _morph_to_vector($$) {
    my ( $morph_cat, $cat_value ) = @_;
    my @vector;
    foreach my $value ( keys %{ $MORPH_TAGS{$morph_cat} } ) {
        push @vector, ( $cat_value eq $value ) ? 1 : 0;
    }
    return @vector;
}

# Strip auxiliar information (such as _;) from lemma
sub _get_bare_lemma($) {
    my $lemma = shift;
    $lemma =~ /^([^-_]*)/;
    return $1;
}

# Returns true, if tokens in given array correspond to a name of city, after concatenation
sub _is_city(@) {
    my @tokens = @_;
    return 0 if @tokens == 0;

    my $city = _get_bare_lemma( $tokens[0] );
    foreach my $i ( 1 .. $#tokens ) {
        $city .= lc " " . _get_bare_lemma( $tokens[$i] );
    }

    return exists $CITIES{$city} ? 1 : 0;
}

# Returns true, if tokens in given array correspond to a name of country, after concatenation
sub _is_country(@) {
    my @tokens = @_;
    return if @tokens == 0;

    my $country = _get_bare_lemma( $tokens[0] );
    foreach my $i ( 1 .. $#tokens ) {
        $country .= " " . _get_bare_lemma( $tokens[$i] );
    }

    return exists $COUNTRIES{$country} ? 1 : 0;
}

sub _is_day_number($) {
    my $token = shift;
    return ($token =~ /^[1-9]$/ || $token =~ /^[12][[:digit:]]$/ || $token =~ /^3[01]$/ ) ? 1 : 0;
}

sub _is_month_number($) {
    my $token = shift;
    return ($token =~ /^[1-9]$/ || $token =~ /^1[12]$/) ? 1 : 0;
}

sub _is_year_number($) {
    my $token = shift;
    return ($token =~ /^[12][[:digit:]][[:digit:]][[:digit:]]$/ ) ? 1 : 0;
}

sub extract_oneword_features {
    my %args = @_;
    my @features;

    # Extract morphological tags
    foreach my $tag_str ( 'pprev_tag', 'prev_tag', 'act_tag' ) {
        my @tags = split //, $args{$tag_str};
        foreach my $tag ( keys %MORPH_TAG_NUMBERS ) {
            push @features, _morph_to_vector( $tag, $tags[ $MORPH_TAG_NUMBERS{$tag} ] );
        }
    }

#    push @features, ( exists $TABU_TAGS{substr $args{'act_tag'}, 0, 1} )    ? 1 : 0;

    # Use lemma hints
    my $lemma = $args{'act_lemma'};
    push @features, ( $lemma =~ /_;Y/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;S/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;E/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;G/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;K/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;R/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;m/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;H/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;U/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;L/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;j/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;g/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;c/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;y/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;b/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;u/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;w/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;p/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;z/ ) ? 1 : 0;
    push @features, ( $lemma =~ /_;o/ ) ? 1 : 0;

    # Orthographic features
    my $bare_lemma = _get_bare_lemma($lemma);
    push @features, ( $bare_lemma =~ /^[[:upper:]]/ )                                   ? 1 : 0;
    push @features, ( $bare_lemma =~ /^[[:upper:]]+$/ )                                 ? 1 : 0; # all upper-case
    push @features, ( $bare_lemma =~ /^([01]?[0-9]|2[0-3])[.:][0-5][0-9]([ap]m)?$/ )    ? 1 : 0; # time
    push @features, ( _is_year_number($bare_lemma) )                                    ? 1 : 0;
    push @features, ( exists $MONTHS{$bare_lemma} )                                     ? 1 : 0;
    push @features, ( $bare_lemma =~ /ová$/ ) ? 1 : 0;

    # Form
    my $form = $args{'act_form'};
    push @features, ( $form =~ /^[[:upper:]]/ ) ? 1 : 0;

    # Built-in lists
    push @features, ( _is_city($lemma) )                    ? 1  : 0;
    push @features, ( exists $CITY_PARTS{$bare_lemma} )     ? 1  : 0;
    push @features, ( exists $STREETS{$bare_lemma} )        ? 1  : 0;
    push @features, ( exists $NAMES{$bare_lemma} )          ? 1  : 0;
    push @features, ( exists $SURNAMES{$bare_lemma} )       ? 1  : 0;
    push @features, ( exists $OBJECTS{$bare_lemma} )        ? 10 : 0;
    push @features, ( exists $INSTITUTIONS{$bare_lemma} )   ? 1 : 0;
    push @features, ( _is_country($lemma) )                 ? 1  : 0;

    # Previous lemma
    my $prev_lemma = $args{'prev_lemma'};
    my $prev_bare_lemma = _get_bare_lemma($prev_lemma);

    push @features, ( $prev_lemma =~ /_;Y/ )                ? 1 : 0;
    push @features, ( exists $NAMES{$prev_bare_lemma} )     ? 1 : 0;
    push @features, ( $prev_bare_lemma eq '/')              ? 1 : 0;
    push @features, ( $prev_bare_lemma eq '.')              ? 1 : 0;
    push @features, ( _is_month_number($prev_lemma) )       ? 1 : 0;
    push @features, ( exists $MONTHS{$prev_lemma} )         ? 1 : 0;

    # Next lemma
    my $next_lemma = $args{'next_lemma'};
    my $next_bare_lemma = _get_bare_lemma($next_lemma);

    push @features, ( $next_lemma =~ /_;S/ )                ? 1 : 0;
    push @features, ( exists $SURNAMES{$next_bare_lemma} )  ? 1 : 0;
    push @features, ( $next_bare_lemma eq '/' )             ? 1 : 0;
    push @features, ( $next_bare_lemma eq '.' )             ? 1 : 0;
    push @features, ( exists $OBJECTS{$next_bare_lemma} )   ? 1 : 0;
    push @features, ( _is_year_number($next_bare_lemma) )   ? 1 : 0;

    return @features;

}


1;
