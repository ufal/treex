package Treex::Tool::Depfix::CS::DiacriticsStripper;
use Moose;
use Treex::Core::Common;
use utf8;

sub strip_diacritics {
    my ($word) = @_;

    $word =~ tr/áčďéěíľňóřšťúůýžÁČĎÉĚÍĽŇÓŘŠŤÚŮÝŽ/acdeeilnorstuuyzACDEEILNORSTUUYZ/;

    return $word;
}

1;

=head1 NAME 

Treex::Tool::Depfix::CS::DiacriticsStripper

=head1 DESCRIPTION

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

