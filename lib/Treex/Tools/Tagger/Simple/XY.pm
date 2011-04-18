package Treex::Tools::Tagger::Simple::XY;
use utf8;
use Moose;
use Treex::Core::Common;
with 'Treex::Tools::Tagger::Role';

# pre-defined interface:

sub tag_and_lemmatize_sentence {
    my ( $self, @wordforms ) = @_;
    my ( @tags, @lemmas );

    # delete the following two lines and fill your code
    @tags = map {'???'} @wordforms;
    @lemmas = @wordforms;
    return ( \@tags, \@lemmas );
}

1;

__END__

=head1 NAME

Treex::Tools::Tagger::Simple::XY - Perl module for tagging ???fill_your_language???.

=head1 SYNOPSIS

  use Treex::Tools::Tagger::Simple::XY;
  my $tagger = Treex::Tools::Tagger::Simple::XY->new();
  my @words = qw(Yesterday I went to the cinema);
  my ($tags_rf, $lemmas_rf) = $tagger->tag_and_lemmatize_sentence(@words);
  while (@words) {
      print shift @words, "\t", shift @{$lemmas_rf}, "\t", shift @{$tags_rf}, "\n";
  }

=head1 COPYRIGHT AND LICENCE

Copyright 2011 ???FILL_YOUR_NAME???

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
