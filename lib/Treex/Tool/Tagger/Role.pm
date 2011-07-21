package Treex::Tool::Tagger::Role;
use Moose::Role;

requires 'tag_and_lemmatize_sentence';

1;

__END__

=head1 NAME

Treex::Tool::Tagger::Role - role for POS taggers

=head1 SYNOPSIS

  package Treex::Tool::Tagger::Simple::XY;
  use Moose;
  with 'Treex::Tool::Tagger::Role';

=head1 REQUIRED METHOD

=head2  my ($tags_rf, $lemmas_rf) = $tagger->tag_and_lemmatize_sentence(@words_forms);

=head1 COPYRIGHT AND LICENCE

Copyright 2011 Martin Popel

This module is free software;
you can redistribute it and/or modify it under the same terms as Perl itself.
