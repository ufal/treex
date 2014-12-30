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

References to arrays of word forms, lemmas, and morphological tags are given as arguments.
Particular parser may not need the lemmas and/or tags.

References to arrays of parent indices (0 stands for artifical root) and analytical functions (deprels) are returned.
For unlabeled parsing, C<$afuns_rf> is C<undef>.

=head1 COPYRIGHT AND LICENCE

Copyright 2011 Martin Popel

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
