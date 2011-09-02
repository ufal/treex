package Treex::Core::Types;
use utf8;
use Moose::Util::TypeConstraints;

subtype 'Treex::Type::NonNegativeInt'
    => as 'Int'
    => where {$_ >= 0}
=> message {"$_ isn't non-negative"};

subtype 'Treex::Type::Selector'
    => as 'Str'
    => where {m/^[a-z\d]*$/i}
=> message {"Selector must =~ /^[a-z\\d]*\$/i. You've provided $_"};    #TODO: this message is not printed

subtype 'Treex::Type::Layer'
    => as 'Str'
    => where {m/^[ptan]$/i}
=> message {"Layer must be one of: [P]hrase structure, [T]ectogrammatical, [A]nalytical, [N]amed entities, you've provided $_"};


__END__

=encoding utf-8

=head1 NAME

Treex::Core::Types - types used in Treex framework

=head1 DESCRIPTION

=head1 TYPES

=over 4

=item Treex::Type::NonNegativeInt

0, 1, 2, ...

=item Treex::Type::Layer

one of: P, T, A, N
case insensitive

=item Treex::Type::Selector

Selector - only alphanumeric characters, may be empty

=back

=head1 AUTHOR

Tomáš Kraut <kraut@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

