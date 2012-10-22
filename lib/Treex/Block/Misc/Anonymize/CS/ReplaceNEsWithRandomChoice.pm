package Treex::Block::Misc::Anonymize::CS::ReplaceNEsWithRandomChoice;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'language'     => ( is => 'rw', isa => 'Str', default  => 'en' );

use Treex::Tool::Lexicon::Generation::CS;
my $generator = Treex::Tool::Lexicon::Generation::CS->new();


my %frequent_names = (
    'pf' => [qw(Jiří Jan Petr Josef Pavel Jaroslav Martin Tomáš Miroslav
               František Zdeněk Václav Michal Karel Milan Vladimír Lukáš David Jakub Ladislav)],
    'ps' => [qw(Novák Svoboda Novotný Dvořák Černý Procházka Kučera Veselý Horák Němec Pospíšil
               Pokorný Marek Hájek Jelínek Král Růžička Beneš Fiala Sedláček)],

		      'ps-f',
		      'ps-m',
		      'ps-f',
		      'ps-m',


);

my %mapping;

sub process_anode {
    my ( $self, $anode ) = @_;

    return if $anode->is_root;

    if ($anode->lemma =~ /;([YS])/) {
        my $lemma = $anode->lemma;
        my $type = $1;

        my $new_lemma = $mapping{$type}{$lemma};

        if (not defined $new_lemma) {
            my $rand_index = rand(scalar(@{$frequent_names{$type}}));
            $new_lemma = $frequent_names{$type}[$rand_index];
            $mapping{$type}{$lemma} = $new_lemma;
        }

        $anode->set_lemma($new_lemma);
        my ($new_form) = map {$_->get_form}
            $generator->forms_of_lemma( $new_lemma, { tag_regex => $anode->tag } );
        $anode->set_form($new_form);

    }
}

binmode STDOUT,":utf8";
binmode STDIN,":utf8";
my %examples;
sub _extract_frequent_examples {
  print 'XXXXXXXXXXXX\n';
  while (<STDIN>) {
    chomp;
    s/^ +//;
    my ($number, $lemma, $tag) = split;
    next if $tag=~/^AU/;
    $lemma =~s/[_-].*?;([A-Z]).*// or next;
    my $netype = $1;
    my $gendernumber = substr($tag,2,2);
    if (not exists $examples{$netype}{$gendernumber} or (keys $examples{$netype}{$gendernumber})<20) {
      $examples{$netype}{$gendernumber}{$lemma} = 1;
    }
#    print "$number $netype $gendernumber $lemma\n"
  }

  foreach my $ne_type (qw(Y S G)) {
    foreach my $gendernumber (keys %{$examples{$ne_type}}) {
      print " $ne_type$gendernumber => qw( ".(join " ",sort keys %{$examples{$ne_type}{$gendernumber}})."),\n";
    }
  }
}


1;

#  ntred -TNe 'print $this->attr("m/lemma")."\t".$this->attr("m/tag")."\n";' | egrep '.;[A-Z]' | sort | uniq -c | sort -nr > sorted
#  cat sorted | perl -e 'use Treex::Block::Misc::Anonymize::CS::ReplaceNEsWithRandomChoice; Treex::Block::Misc::Anonymize::CS::ReplaceNEsWithRandomChoice::_extract_frequent_examples()'

=head1 NAME

Treex::Block::Misc::ReplacePersonalNamesCS

=head1 DESCRIPTION

Replace personal names (first names as well as surnames, signalled by lemma suffix)
by new names randomly chosen from the most frequent Czech names. Inflect the new names
accordingly to the morphological tag of original names.

=head1 AUTHOR

Zdeněk Žabokrtský

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
