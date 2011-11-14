package Treex::Tool::Lexicon::EN::First_names;
use utf8;
use strict;
use warnings;
use autodie;

#TODO: Better way how to make it automatically download.
my $FN = 'data/models/lexicon/en/first_names.tsv';
use Treex::Core::Resource qw(require_file_from_share);
my $file_path = require_file_from_share( $FN, 'Treex::Tool::Lexicon::EN::First_names' );

my %GENDER_OF;
open my $F, '<:encoding(utf8)', $file_path;
while (<$F>) {
    chomp;
    my ( $name, $f_or_m ) = split /\t/, $_;
    $GENDER_OF{$name} = $f_or_m;
}
close $F;

sub gender_of {
    my ($first_name) = @_;
    return $GENDER_OF{ lc $first_name };
}

1;

__END__

=head1 NAME

Treex::Tool::Lexicon::EN::First_names

=head1 SYNOPSIS

 use Treex::Tool::Lexicon::EN::First_names;
 print Treex::Tool::Lexicon::EN::First_names::gender_of('John'); # prints m
 print Treex::Tool::Lexicon::EN::First_names::gender_of('Mary'); # prints f
       Treex::Tool::Lexicon::EN::First_names::gender_of('XYZW'); # returns undef

=head1 DESCRIPTION

This module should include support for miscellaneous queries
involving English lexicon and morphology.  

=cut

# Copyright 2010 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
