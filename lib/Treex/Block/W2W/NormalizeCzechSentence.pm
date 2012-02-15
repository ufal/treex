package Treex::Block::W2W::NormalizeCzechSentence;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';


sub process_zone {
    my ( $self, $zone ) = @_;

    # get the source sentence and normalize
    my $sentence = $zone->sentence;
    $sentence =~ s/^\s+//;
    log_fatal("No sentence to normalize!") if !defined $sentence;
    my $outsentence = $self->normalize_sentence($sentence);

    $zone->set_sentence($outsentence);
    return 1;
}


sub normalize_sentence {
    my ( $self, $s ) = @_;

    $s = fix_tokenized_Czech_decimal_numbers($s);
    $s = fix_Czech_quotation_pairs($s);

    # whitespace
    $s =~ s/\x{00A0}/ /g;  # nbsp
    $s =~ s/&nbsp;/ /gi;  # nbsp
    $s =~ s/\s+/ /g;
    # quotation marks
    #$s =~ s/,,/"/g;
    #$s =~ s/``/"/g;
    #$s =~ s/''/"/g;
    #$s =~ s/[“”„‟«»]/"/g;
    # single quotation marks
    #$s =~ s/[´`'‘’‚‛]/'/g;
    $s =~ s/[´`’‛]/'/g; # these are not valid Czech ‚...‘

    # dashes
    $s =~ s/[-–­֊᠆‐‑‒–—―⁃⸗﹣－⊞⑈︱︲﹘]+/-/g;
    # dots
    $s =~ s/…/.../g;

    return $s;
}

sub fix_tokenized_Czech_decimal_numbers {
  # try to improve malformed input
  $_ = shift;
  # print STDERR "BEF $_\n";
  return $_ if /[0-9],[0-9]/;
    # evidence that this sentence is correct

  if (/[0-9] *, +[0-9]{1,3} ?(%|(mili?[óo]n[ůu]|miliardy?|%|let[áýé]|µg|l|měsíc(e|ících|ů)|ml|mg|dolar[ůy]|dolarech|americk(ých|ým|é)|ti|let|mmol|mikrogram(ům|y|ech)|kg|ng|násob(ek|ku|ky)|fraktur|rok[ůyu])\b)/
    || /\b(o|na) [0-9]{1,3} *, +[0-9]{1,3}/
    || /\b(od|z) [0-9]{1,3} *, +[0-9]{1,3} (do|na)\b/
    || /\D +\d{1,3} *, \d{1,3} (a|až|-+) [0-9]{1,3} *, +[0-9]{1,3} /
    || /index.*klesl/ || /richterov.*škál/i) {
    # this is wrong
    my $old;
    do {
      $old = $_;
      $_ =~ s/(([^[:digit:]] |^|[[:punct:]])[0-9]{1,3}) *, +([0-9]{1,3} ?([^[:digit:]])|$|[[:punct:]])/$1,$3/g;
    } while ($_ ne $old);
  }
  # print STDERR "AFT $_\n";
  return $_;
}

my $quo = "„“”\"";
my $apo = "‚‘’‛`'";
my $noquo = "[^$quo]";
my $noapo = "[^$apo]";
my $noquoapo = "[^$quo$apo]";
# my @single_pairs = map {[split /---/,$_]} qw( ‚---‘  );
my $doubleopenmark = "DoUbLeOpEnMaRk";
my $doubleclosemark = "DoUbLeClOsEMaRk";
my $singleopenmark = "SiNgLeOpEnMaRk";
my $singleclosemark = "SiNgLeClOsEMaRk";
sub fix_Czech_quotation_pairs {
  my $s = shift;

  $s =~ s/„($noquo*)“/$doubleopenmark$1$doubleclosemark/go;
  $s =~ s/„($noquo*)”/$doubleopenmark$1$doubleclosemark/go;
  $s =~ s/“($noquo*)”/$doubleopenmark$1$doubleclosemark/go;
  $s =~ s/„($noquo*)"/$doubleopenmark$1$doubleclosemark/go;
  $s =~ s/"($noquo*)"/$doubleopenmark$1$doubleclosemark/go;
  $s =~ s/,,($noquoapo*)"/$doubleopenmark$1$doubleclosemark/go;
  $s =~ s/,,($noquoapo*)``/$doubleopenmark$1$doubleclosemark/go;
  $s =~ s/``($noquoapo*)''/$doubleopenmark$1$doubleclosemark/go;

  $s =~ s/,,($noquo*)"/$doubleopenmark$1$doubleclosemark/go;
  $s =~ s/,,($noquo*)``/$doubleopenmark$1$doubleclosemark/go;
  $s =~ s/``($noquo*)''/$doubleopenmark$1$doubleclosemark/go;

  $s =~ s/`($noapo*)'/$singleopenmark$1$singleclosemark/go;
  $s =~ s/‚($noapo*)‘/$singleopenmark$1$singleclosemark/go;
  $s =~ s/‘($noapo*)’/$singleopenmark$1$singleclosemark/go;

  $s =~ s/"( )/$doubleclosemark$1/go;
  $s =~ s/"$/$doubleclosemark/go;
  $s =~ s/"([[:punct:]])$/$doubleclosemark$1/go;
  $s =~ s/( )"/$1$doubleopenmark/go;
  $s =~ s/^"/$doubleopenmark/go;
  $s =~ s/(\S)''/$1$doubleclosemark/go;
  $s =~ s/(\S)``/$1$doubleclosemark/go;
  $s =~ s/''(\S)/$doubleopenmark$1/go;
  $s =~ s/``(\S)/$doubleopenmark$1/go;

  $s =~ s/$doubleopenmark/„/go;
  $s =~ s/$doubleclosemark/“/go;

  $s =~ s/$singleopenmark/‚/go;
  $s =~ s/$singleclosemark/‘/go;

  return $s;
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2W::NormalizeCzechSentence - Modifies Czech sentence in place

=head1 DESCRIPTION

Modify english_source_sentence in place for a better normalization.
E.g. contracted negations are expanded etc.

=head1 METHODS

=over 4

=item normalize_sentence()

this method can be overridden in more advanced normalizers

=item process_zone()

this loops over all sentences

=back

=head1 AUTHOR

Ondrej Bojar <bojar@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
