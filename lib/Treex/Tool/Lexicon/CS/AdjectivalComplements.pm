package Treex::Tool::Lexicon::CS::AdjectivalComplements;

use strict;
use warnings;
use utf8;

# Czech verbs that require an adjectival complement in nominative case
my $adj1 = "cítit_se|cítívat_se|přijít|zůstávat|zůstat|chodit|narodit_se|ponechávat|ponechat|nechat|nechávat|uchovávat_se|
uchovat_se|vypadat|ukazovat_se|ukázat_se|jevit_se|připadat|připadávat|zdát_se|zdávat_se|prokázat_se|prokazovatse";

# Czech verbs that require an adjectival complement in accusative case
my $adj4 = "mít|nahlížet|nahlédnout|nechat|nechávat|představovat_si|představit_si|přidržovat|přidržet|uchovávat|uchovat|vidět|
zachovávat|zachovat|zanechávat|zanechat|udržovat|udržet";

# Czech verbs that require an adjectival complement in instrumental case
my $adj7 = "ukazovat_se|ukázat_se|jevit_se|připadat|připadávat|zdát_se|zdávat_se|prokázat_se|prokazovat_se|udržovat|udržet|
uznat|uznávat";

sub requires {

    my ( $lemma, $case ) = @_;

    return 0 if $case !~ m/^[147]$/;

    if ( $case eq '1' ) {
        return $lemma =~ m/^($adj1)$/sxm;
    }
    elsif ( $case eq '4' ) {
        return $lemma =~ m/^($adj4)$/sxm;
    }
    return $lemma =~ m/^($adj7)$/sxm;
}

1;

__END__

=pod

=head1 NAME

Treex::Tool::Lexicon::CS::AdjectivalComplements

=head1 SYNOPSIS

 use Treex::Tool::Lexicon::CS::AdjectivalComplements;
 
 foreach my $lemma (qw(mít nechat zůstávat)) {
     if ( Treex::Tool::Lexicon::CS::Reflexivity::requires($lemma, 4) ){
         print "$lemma requires adjectival complement in the 4th case.\n";
     }
 }
 
=head1 DESCRIPTION

=over 4

=item my $corrected_tlemma = Treex::Tool::Lexicon::CS::AdjectivalComplements::requires( $tlemma, $case );

Returns true if the given lemma requires a strictly adjectival complement (not a noun) in the given case.

The list of lemmas is based on a manual evaluation of Vallex 2.5 entries.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
