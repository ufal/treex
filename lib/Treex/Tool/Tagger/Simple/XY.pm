package Treex::Tool::Tagger::Simple::XY;
use utf8;
use Moose;
use Treex::Core::Common;
with 'Treex::Tool::Tagger::Role';

# pre-defined interface:

sub tag_sentence {
    my ( $self, $words_rf ) = @_;
    my ( @tags, @lemmas );

    # delete the following two lines and fill your code
    @tags = map {'???'} @$words_rf;
    @lemmas = map {lc} @$words_rf;
    return ( \@tags, \@lemmas );
}

1;

__END__

=head1 NAME

Treex::Tool::Tagger::Simple::XY - ???fill_your_language??? PoS tagging

=head1 SYNOPSIS

  use Treex::Tool::Tagger::Simple::XY;
  my $tagger = Treex::Tool::Tagger::Simple::XY->new();
  my @words = qw(Yesterday I went to the cinema);
  my ($tags_rf, $lemmas_rf) = $tagger->tag_sentence(\@words);
  while (@words) {
      print shift @words, "\t", shift @{$lemmas_rf}, "\t", shift @{$tags_rf}, "\n";
  }

=head1 COPYRIGHT AND LICENCE

Copyright 2012 ???FILL_YOUR_NAME???

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
