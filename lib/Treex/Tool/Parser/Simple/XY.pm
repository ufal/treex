package Treex::Tool::Parser::Simple::XY;
use utf8;
use Moose;
use Treex::Core::Common;
with 'Treex::Tool::Parser::Role';

# optional parameters or instance attributes
#has coordination_style => (
#    is => 'ro', # this generates a getter method $self->coordination_style();
#    isa => 'Str',
#    default => 'PDT-like',
#);

# pre-defined interface:
sub parse_sentence {
    my ( $self, $wordforms_rf, $lemmas_rf, $tags_rf ) = @_;
    my (@parents, @afuns);

    # delete the following two linea and fill your code
    @parents = map {0} @$wordforms_rf;
    @afuns   = map {'NR'} @$wordforms_rf;
    
    return (\@parents, \@afuns);
}

1;

__END__

=head1 NAME

Parser::Simple::XY - Perl module for tagging ???fill_your_language???.

=head1 SYNOPSIS

  use Treex::Tool::Parser::Simple::XY;
  my $parser = Treex::Tool::Parser::Simple::XY->new();
  my @words  = qw(Yesterday I went to the cinema);
  my @lemmas = qw(yesterday I go to the cinema);
  my @tags = qw(R P V P D N); 
  my ($parents_rf, $afuns_rf) = $parser->parse_sentence(\@words,\@lemmas,\@tags);
  while (@words) {
      print shift @words,"\t",shift @$parents_rf,"\n";
  }

=head1 COPYRIGHT AND LICENCE

Copyright 2011 ???FILL_YOUR_NAME???

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
