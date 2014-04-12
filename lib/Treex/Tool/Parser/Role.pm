package Treex::Tool::Parser::Role;
use Moose::Role;

requires 'parse_sentence';

1;

__END__

=head1 NAME

Treex::Tool::Parser::Role - role for dependency parsers

=head1 SYNOPSIS

  package Treex::Tool::Parser::Simple::XY;
  use Moose;
  with 'Treex::Tool::Parser::Role';

=head1 REQUIRED METHOD

=head2 my ($parent_ords_rf, $afuns_rf) = $parser->parse_sentence(\@forms, \@lemmas, \@tags);  

=head1 COPYRIGHT AND LICENCE

Copyright 2011 Martin Popel

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
