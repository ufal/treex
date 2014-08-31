package Treex::Tool::Tagger::Role;

use strict;
use warnings;
use Moose::Role;

requires 'tag_sentence';

1;

__END__

=head1 NAME

Treex::Tool::Tagger::Role - role for PoS taggers

=head1 SYNOPSIS

  package Treex::Tool::Tagger::Simple::XY;
  use Moose;
  with 'Treex::Tool::Tagger::Role';

=head1 REQUIRED METHODS

=head2 new({lemmatize=>1,...})

If the constructor parameter C<lemmatize> has a true value and
the tagger does not support lemmatization, it should immediately log_fatal.
If <lemmatize> is false, the tagger can save some resources
by not doing the lemmatization (i.e. method C<tag_sentence> returning just C<$tags_rf>).
If the additional cost of lemmatization is low, the tagger may always lemmatize
(i.e. ignoring the C<lemmatize> parameter).

=head2  my ($tags_rf, $lemmas_rf) = $tagger->tag_sentence(\@words_forms);

If the tagger does not support lemmatization, it may return just C<$tags_rf>.

=head1 COPYRIGHT AND LICENCE

Copyright 2012 Martin Popel

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
