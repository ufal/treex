package Treex::Block::HamleDT::Test::UD::UnderscoreInForm;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
extends 'Treex::Block::Test::BaseTester';

sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $form = $node->form();
    if(!defined($form) || $form =~ m/_/)
    {
        $self->complain($node, 'Word form must be defined and must not contain an underscore.');
    }
}

1;

=over

=item Treex::Block::HamleDT::Test::UD::UnderscoreInForm

Word forms should not contain the underscore (“_”) character. If a word form
consists just of the underscore character, it probably means that the word is
empty and it was encoded using underscore because empty strings are not allowed
in the CoNLL-U file format. If the underscore occurs between two parts of the
word form, it probably means that a multi-word expression has been collapsed
into a single node. None of these two situations is permitted.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
