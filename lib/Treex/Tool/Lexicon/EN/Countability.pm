package Treex::Tool::Lexicon::EN::Countability;
use utf8;
use strict;
use warnings;
use autodie;
use Treex::Core::Resource qw(require_file_from_share);

my $DATA_FILE = 'data/models/lexicon/en/countability.tsv';
my $file_path = require_file_from_share( $DATA_FILE, 'Treex::Tool::Lexicon::EN::Countability' );

my %COUNTABILITY;
open my $F, '<:encoding(utf8)', $file_path;
while (<$F>) {
    chomp;
    my ( $lemma, $countability ) = split /\t/, $_;
    $COUNTABILITY{$lemma} = $countability;
}
close $F;

sub countability {
    my ($lemma) = @_;
    return $COUNTABILITY{$lemma} // '';       
}

1;

__END__

=encoding utf8

=head1 NAME

Treex::Tool::Lexicon::EN::Countability

=head1 SYNOPSIS

 use Treex::Tool::Lexicon::EN::Countability;
 print Treex::Tool::Lexicon::EN::PersonalRoles::countability('sugar');
 # prints 'uncountable'

=head1 DESCRIPTION

Return noun countability based on Jan Ptáček's Wordnet::Query module data (extracted
from BNC article counts). 

=head1 AUTHOR

Ondřej Dušek <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
