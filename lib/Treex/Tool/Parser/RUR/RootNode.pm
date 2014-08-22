package Treex::Tool::Parser::RUR::RootNode;

use Moose;

extends 'Treex::Tool::Parser::RUR::Node';

has ord => (
    isa     => 'Int',
    is      => 'ro',
    default => 0,
);

has parent => (
    isa     => 'Maybe[Treex::Tool::Parser::RUR::Node]',
    is      => 'ro',
    default => undef,
);

has parentOrd => (
    isa     => 'Int',
    is      => 'rw',
    default => -1,
);

has label => (
    isa     => 'Str',
    is      => 'rw',
    default => 'AuxS',
);

1;

__END__

=pod

=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::Parser::RUR::RootNode

=head1 DESCRIPTION

Represents the technical root of a sentence.

=head1 FIELDS

All fields are read-only and have the following values.
Root node can be easily recognized by its ord value C<0>.

=over 4

=item form =

=item lemma =

=item tag = '#root#'

=item ord = 0

=item parent = -1

This should never be read.

=item parentOrd = undef

This should never be read.

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
