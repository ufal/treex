package Treex::Tool::Lexicon::NL::Pronouns;

use utf8;
use strict;
use warnings;

sub is_wh_pronoun {
    my ($word) = @_;
    return $word =~ /^(waar|wie|wat|hoe|welke?|wiens|wiens|hoeveel|wanneer|waarom)$/;
}


my $RELATIVE_PRONOUNS = qr{die|dat|hetgeen|
    waaraan|waarachter|waaraf|waarbij|waarboven|
    waarbuiten|waardoor|waardoorheen|waarheen|waarin|waarjegens|
    waarmede|waarmee|waarna|waarnaar|waarnaartoe|waarnaast|waaronder|
    waarop|waarover|waaroverheen|waarrond|waartegen|waartegenin|
    waartoe|waartussen|waartussenuit|waaruit|waarvan|waarvandaan|waarvoor}ix;

sub is_relative_pronoun {
    my ($word) = @_;
    return 1 if is_wh_pronoun($word);
    return $word =~ /^($RELATIVE_PRONOUNS)$/;
}


1;

__END__
=encoding utf8

=head1 NAME

Treex::Tool::Lexicon::NL::Pronouns

=head1 SYNOPSIS

 
=head1 DESCRIPTION


=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
