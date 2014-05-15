package Treex::Block::A2T::CS::MarkReflpronCoref;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::MarkReflpronCoref';

override '_is_refl_pronoun' => sub {
    my ($self, $t_node) = @_;
    return $t_node->get_lex_anode->tag =~ /^.[678]/;
};

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::CS::MarkReflpronCoref

=head1 DESCRIPTION

Coreference link between a t-node corresponding to reflexive pronoun (inc. reflexive possesives)
and its antecedent (in the sense of grammatical coreference) is detected in Czech t-trees
and stored in the C<coref_gram.rf> attribute.

Czech reflexive pronouns are detected using PDT-style tagset.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
