package Treex::Block::Misc::ProjectAndConcatAttribs;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;

    my ($aligned_nodes_rf,$types_rf) = $cs_tnode->get_directed_aligned_nodes;
    foreach my $en_tnode (@$aligned_nodes_rf) {
        $en_tnode->set_t_lemma($en_tnode->t_lemma.'='.$cs_tnode->t_lemma);
        $en_tnode->set_formeme($en_tnode->formeme.'='.$cs_tnode->formeme);
    }
}

1;

=head1 NAME

Treex::Block::Misc::ProjectAndConcatAttribs;

=head1 DESCRIPTION

Project cs t-lemmas and formemes from cs to en and
concatenate them (a temporary auxiliary block for
experiments on segmentation of parallel trees).

=head1 AUTHOR

Zdenek Zabokrtsky

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
