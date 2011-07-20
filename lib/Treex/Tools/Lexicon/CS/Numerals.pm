package Treex::Tools::Lexicon::CS::Numerals;

use strict;
use warnings;
use utf8;

# Returns 1 for non-congruent numerals, i.e. indefinite "(ně)kolik" etc. or definite fraction or 5 and higher
sub is_noncongr_numeral {

    my ( $lemma, $tag ) = @_;

    return ( $tag =~ m/^C[\?any]..[14]/ or ( $tag =~ m/^C=/ and $lemma =~ m/^([5-9]|[1-9][0-9]+|[0-9]+\.[0-9]+)$/ ) );
}

1;

__END__

=pod

=head1 NAME

Treex::Tools::Lexicon::CS::Numerals

=head1 SYNOPSIS

    my $bool = is_noncongr_numeral( 'pět-1`5', 'Cn-S4----------' ); # returns 1
    $bool    = is_noncongr_numeral( 'pět-1`5', 'Cn-P2----------' ); # returns 0
    $bool    = is_noncongr_numeral( '2.35',    'C=-------------' ); # returns 1
    $bool    = is_noncongr_numeral( '2',       'C=-------------' ); # returns 0

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
