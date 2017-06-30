package Treex::Block::HamleDT::Test::UD::CopulaIsAux;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    if($node->deprel() eq 'cop' && $node->tag() ne 'AUX')
    {
        $self->complain($node, $node->form());
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::CopulaIsAux

Only auxiliary verbs serve as copulas (if the language has copulas at all).
We may argue whether verbs other than "to be" can be copulas. But they definitely should be tagged AUX, not VERB (since UD v2).

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016, 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
