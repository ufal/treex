package Treex::Block::A2A::EN::Retokenize;
use Moose;
use Treex::Core::Common;
use utf8;
use Treex::Block::W2A::EN::Tokenize;
extends 'Treex::Block::A2A::Retokenize';

override 'process_start' => sub {
    my ($self) = @_;

    $self->set_tokenizer(Treex::Block::W2A::EN::Tokenize->new());

    return;
};

1;

=head1 NAME 

Treex::Block::A2A::EN::Retokenize -- fix wrong English tokenization

Bonus: can also try to fix alignment for the retokenized nodes.

=head1 DESCRIPTION

=head1 PARAMETERS

=over

=item fix_alignment
If there is alignment from the retokenized node to several other nodes,
try to distribute the alignment links over the new nodes based on simple heuristics.
Default is C<0> -- copy all alignment links to all newly created nodes.

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

