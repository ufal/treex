package Treex::Block::W2W::NormalizeEnglishSentence;
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

my %repl = (
  "can't" => "can not",
  "cannot" => "can not",
  "ain't" => "is not",
  "won't" => "will not",
  "I'm" => "I am",
  ( map { my $e = $_; $e =~ s/'ve/ have/; ($_, $e); }
      qw(I've you've we've they've) ),
  ( map { my $e = $_; $e =~ s/'ll/ will/; ($_, $e); }
      qw(I'll you'll we'll they'll he'll she'll) ),
  ( map { my $e = $_; $e =~ s/'re/ are/; ($_, $e); }
      qw(you're they're we're) ),
  ( map { my $e = $_; $e =~ s/n't/ not/; ($_, $e); }
      qw(isn't aren't wasn't weren't don't doesn't didn't
      shouldn't wouldn't couldn't mustn't needn't
      hasn't haven't hadn't) ),
);

sub normalize_sentence {
    my ( $self, $s ) = @_;

    # fix random clear errors
    $s =~ s/\b(Haven't|Don't|wasn't|shouldn't|couldn't|can't|didn't|wouldn't|aren't)(you|we|get|have|worry|wait|tell|do|place|figure|care|fix|move|think|so|just|feel)\b/$1 $2/ig;

    # whitespace
    $s =~ s/\x{00A0}/ /g;  # nbsp
    $s =~ s/[&%]\s*nbsp\s*;/ /gi;  # nbsp
    $s =~ s/\s+/ /g;
    # quotation marks
    $s = fix_English_quotation_pairs($s);

# These were just rules to drop them.
#    $s =~ s/``/"/g;
#    $s =~ s/''/"/g;
#    $s =~ s/[“”„‟«»]/"/g;

    # single quotation marks
    # $s =~ s/[´`'‘’‚‛]/'/g; # not the full set, only those that were seen in contracted forms
    $s =~ s/[´'’‛]/'/g;

    # dashes
    $s =~ s/[-–­֊᠆‐‑‒–—―⁃⸗﹣－⊞⑈︱︲﹘]+/-/g;

    # contracted negation and other contractions
    foreach my $contr (keys %repl) {
      my $exp = $repl{$contr};
      foreach my $func (qw(lc ucfirst uc)) {
        my $c = eval("$func(\$contr)");
        my $e = eval("$func(\$exp)");
        $s =~ s/\b$c\b/$e/g;
        $s =~ s/([_*])$c\1/$e/g; # touch also if _highlighted_
      }
    }

    print STDERR "FOO: $s\n";
    $s =~ s/ n't / not /g;

    return $s;
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

sub fix_English_quotation_pairs {
  my $s = shift;

  $s =~ s/“($noquo*)”/$doubleopenmark$1$doubleclosemark/go;
  $s =~ s/"($noquo*)"/$doubleopenmark$1$doubleclosemark/go;
  $s =~ s/``($noquoapo*)''/$doubleopenmark$1$doubleclosemark/go;

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

  $s =~ s/$doubleopenmark/“/go;
  $s =~ s/$doubleclosemark/”/go;

  $s =~ s/$singleopenmark/‘/go;
  $s =~ s/$singleclosemark/’/go;

  return $s;
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2W::NormalizeEnglishSentence - Modifies English sentence in place

=head1 VERSION

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
