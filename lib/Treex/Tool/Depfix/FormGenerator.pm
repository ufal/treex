package Treex::Tool::Depfix::FormGenerator;
use Moose;
use Treex::Core::Common;
use utf8;

sub get_form {
    my ( $self, $lemma, $tag ) = @_;

    log_fatal "get_form is abstract";

    return;
}

# changes the tag in the node and regebnerates the form correspondingly
sub regenerate_node {
    my ( $self, $node ) = @_;

    log_fatal "regenerate_node is abstract";

    return;
}

1;

=head1 NAME 

Treex::Tool::Depfix::FormGenerator

=head1 DESCRIPTION

This package provides the L<get_form> method,
which tries to generate the wordform
corresponding to the given lemma and tag.

=head1 METHODS

=over

=item my $form = $formGenerator->get_form($lemma, $tag)

Returns the form corresponding to the given lemma and tag, 
or C<undef> if no form can be generated.
In such case, it also issues the following warning:
"Can't find a word for lemma '$lemma' and tag '$tag'."

=back

=head1 AUTHOR

David Marecek <marecek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
