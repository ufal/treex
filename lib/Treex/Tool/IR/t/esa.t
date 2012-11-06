#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;

use MooseX::Types::Moose qw( Int Num );

BEGIN {
    Test::More::plan( skip_all => 'these tests require export AUTHOR_TESTING=1' ) if !$ENV{AUTHOR_TESTING};

    use_ok('Treex::Tool::IR::ESA');
}

# TODO fix the exception handling in Java class and add also OOV examples
my @data = (
    "New York",
    "city",
    "find",
    "Frank Zappa",
    "Volapük",
    "Bedřich Ščerban",
    "The presidential candidates spent Monday frantically criss-crossing the crucial battleground states including Ohio, Florida, Iowa and Virginia, making final appeals to voters. Their task: Push their own supporters to the polls while persuading the sliver of undecided voters to back them.",
);

my $esa = new_ok('Treex::Tool::IR::ESA');

foreach my $text (@data) {
    my %vector = $esa->esa_vector_n_best($text, 10);

    my @keys = keys %vector;
    my @values = values %vector;
    ok( scalar @keys <= 10, "correct size of the n_best list");

    my @key_is_int = grep {is_Int($_)} @keys;
    my @val_is_num = grep {is_Num($_)} @values;
    is(scalar @keys, scalar @key_is_int, "all keys integer");
    is(scalar @values, scalar @val_is_num, "all values numeric");
}

done_testing();
