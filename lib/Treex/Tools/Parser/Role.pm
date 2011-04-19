package Treex::Tools::Parser::Role;
use Moose::Role;

requires 'parse_sentence';

1;

__END__

=head1 NAME

Treex::Tools::Parser::Role - role for dependency parsers

=head1 SYNOPSIS

  package Treex::Tools::Parser::Simple::XY;
  use Moose;
  with 'Treex::Tools::Parser::Role';

=head1 REQUIRED METHOD

=head2 my @parent_ords = $parser->parse_sentence(\@forms, \@lemmas, \@tags);  

=head1 COPYRIGHT AND LICENCE

Copyright 2011 Martin Popel

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
