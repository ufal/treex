package Treex::Tool::Lexicon::CS::NamedEntityLabels;

use strict;
use warnings;
use utf8;

use Treex::Tool::Lexicon::CS;

my %CONGR_LABELS;
my @CONGR_LABELS = qw(hora hrad hrádek kopec legenda městečko město metropole obec osobnost řeka ves vesnice 
vesnička víska);
foreach my $lemma (@CONGR_LABELS) {
    $CONGR_LABELS{$lemma} = 1;
}

my %INCON_LABELS;
my @INCON_LABELS = qw(agentura automobil bar brožura cup Cup časopis dílo divize dům film firma fond fotka foto fotografie 
hit informace kancelář kauza klub kniha konference kraj lázně model motel motocykl nakladatelství noviny obrázek oddělení okres 
palác penzión píseň písnička počítač podnik rádio rotačka rubrika řada seriál série skladba skupina snímek software soutěž spis 
společnost stadion stanice symfonie sympózium telenovela televize třída úřad ústav vůz výstava výstaviště veletrh vydavatelství 
zařízení závod);

foreach my $lemma (@INCON_LABELS) {
    $INCON_LABELS{$lemma} = 1;
}


sub is_label {
    my ($lemma) = @_;
    return 'congr' if ($CONGR_LABELS{ Treex::Tool::Lexicon::CS::truncate_lemma( $lemma, 1 ) });
    return 'incon' if ($INCON_LABELS{ Treex::Tool::Lexicon::CS::truncate_lemma( $lemma, 1 ) });
    return '';
}

my %GEO_LABELS;
my @GEO_LABELS = qw(hora hrad hrádek kopec městečko město metropole obec řeka ves vesnice vesnička víska);

foreach my $lemma (@GEO_LABELS) {
    $GEO_LABELS{$lemma} = 1;
}

# Returns 1 if the given lemma can be a congruent label of a geographic named entity 
sub is_geo_congr_label {
    my ($lemma) = @_;
    return $GEO_LABELS{$lemma} ? 1 : 0;
}

1;

__END__

=encoding utf8

=head1 NAME

Treex::Tool::Lexicon::CS::NamedEntityLabels

=head1 SYNOPSIS

    use Treex::Tool::Lexicon::CS::NamedEntityLabels;
       
    print Treex::Tool::Lexicon::CS::NamedEntityLabels::is_label('hrad');  # prints 'congr'
    print Treex::Tool::Lexicon::CS::NamedEntityLabels::is_label('firma'); # prints 'incon'
    
    print Treex::Tool::Lexicon::CS::NamedEntityLabels::is_geo_congr_label('obec'); # prints 1
    

=head1 DESCRIPTION

This module provides lists of words that are syntactic parents either to incongruent or congruent named entity labels,
e.g. 'město<-Praha' (nominative), 'města<-Prahy' (genitive) is congruent, whereas 'firma<-Beta' (nominative)
'firmy<-Beta' (genitive) is not.

=head1 METHODS

=over

=item is_label( $lemma )

Returns 'congr' for lemmas that can carry a case-congruent ID label which doesn't have to be congruent in number and gender,
e.g. "řeka Rýn", "ves Štěchovice", "město Praha" etc., 'incon' for lemmas  that always carry case-incongruent ID labels,
even if they are congruent in number and gender, e.g. "model Favorit", "okres Hradec", "firma Nova", "rádio Echo".

Returns '' if the word is not found in any of the lists.

=item is_geo_congr_label( $lemma )

Returns 1 if the given lemma is a congruent label of a geographic named entity, e.g. 'obec' or 'hrad'.  

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
