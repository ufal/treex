package Treex::Core::Phrase::NTerm;

use utf8;
use namespace::autoclean;

use Moose;
use Treex::Core::Log;
use Treex::Core::Node;

extends Treex::Core::Phrase;



has children =>
(
    is       => 'rw',
    isa      => 'Array[Treex::Core::Node]',
    required => 1
);



1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Core::Phrase::NTerm

=head1 DESCRIPTION

C<NTerm> is a nonterminal C<Phrase>. It contains (refers to) one or more child
C<Phrase>s.
See L<Treex::Core::Phrase> for more details.

=head1 ATTRIBUTES

=over

=item children

Array of (references to) C<Phrase> objects that are children of this phrase,
i.e. they are subphrases.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
