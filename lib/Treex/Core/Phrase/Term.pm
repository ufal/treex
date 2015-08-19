package Treex::Core::Phrase::Term;

use utf8;
use namespace::autoclean;

use Moose;
use Treex::Core::Log;
use Treex::Core::Node;

extends 'Treex::Core::Phrase';



has node =>
(
    is       => 'ro',
    isa      => 'Treex::Core::Node',
    required => 1
);



1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Core::Phrase::Term

=head1 DESCRIPTION

C<Term> is a terminal C<Phrase>. It contains (refers to) one C<Node> and it can
be part of nonterminal phrases (C<NTerm>).
See L<Treex::Core::Phrase> for more details.

=head1 ATTRIBUTES

=over

=item node

Refers to the C<Node> wrapped in this terminal phrase.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013, 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
