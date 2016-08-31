package Treex::Block::A2T::EN::MarkReflpronCoref;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Coreference::NodeFilter::PersPron;

extends 'Treex::Block::A2T::MarkReflpronCoref';

override '_is_refl_pronoun' => sub {
    my ($self, $t_node) = @_;
    return (Treex::Tool::Coreference::NodeFilter::PersPron::is_reflexive($t_node));
};

1;
__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::EN::MarkReflpronCoref

=head1 DESCRIPTION

Coreference link between a t-node corresponding to reflexive pronoun (inc. reflexive possesives)
and its antecedent (in the sense of grammatical coreference) is detected in English t-trees
and stored in the C<coref_gram.rf> attribute.

English reflexive pronouns are detected the lemma.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
