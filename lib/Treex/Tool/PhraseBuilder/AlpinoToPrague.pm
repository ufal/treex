package Treex::Tool::PhraseBuilder::AlpinoToPrague;

use utf8;
use namespace::autoclean;

use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Log;

extends 'Treex::Tool::PhraseBuilder::ToPrague';



#------------------------------------------------------------------------------
# Examines a nonterminal phrase and tries to recognize certain special phrase
# types. This is the part of phrase building that is specific to expected input
# style and desired output style. This method is called from the core phrase
# building implemented in Treex::Core::Phrase::Builder, after a new nonterminal
# phrase is built.
#------------------------------------------------------------------------------
sub detect_special_constructions
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # The root node must not participate in any specialized construction.
    unless($phrase->node()->is_root())
    {
        # Despite the fact that we work bottom-up, the order of these detection
        # methods matters. There may be multiple special constructions on the same
        # level of the tree, for example coordination of prepositional phrases.
        # However, it should not matter in the Alpino style.
        $phrase = $self->detect_alpino_coordination($phrase);
        $phrase = $self->detect_alpino_clause($phrase);
        $phrase = $self->detect_stanford_pp($phrase);
        # The Alpino treebank has finite auxiliary verbs as heads of participles.
        $phrase = $self->detect_auxiliary_head($phrase);
    }
    # Return the resulting phrase. It may be different from the input phrase.
    return $phrase;
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::PhraseBuilder::AlpinoToPrague

=head1 DESCRIPTION

Derived from C<Treex::Core::Phrase::Builder>, this class implements language-
and treebank-specific phrase structures.

It expects that the dependency relation labels have been translated to the
Prague dialect. The expected tree structure features Alpino coordination
(same shape as Prague but the relation between coordination and its parent is
stored at the coordination head)
and prepositional phrases with the function marked at the head preposition.
The target style is Prague.

Input treebanks for which this builder should work include Alpino (Dutch) and
the Penn Treebank (English) converted for the CoNLL 2007 shared task.

=head1 METHODS

=over

=item build

Wraps a node (and its subtree, if any) in a phrase.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
