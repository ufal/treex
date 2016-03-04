package Treex::Tool::PhraseBuilder::StanfordToUD;

use utf8;
use namespace::autoclean;

use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Log;

extends 'Treex::Tool::PhraseBuilder::ToUD';



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
        ###!!! The following comment should be modified and maybe the order
        ###!!! of the following calls too. Stanford-to-UD conversion does not
        ###!!! work with the PrepArg label.
        # Despite the fact that we work bottom-up, the order of these detection
        # methods matters. There may be multiple special constructions on the same
        # level of the tree. For example: coordination of prepositional phrases.
        # The first conjunct is the head of the coordination and it is also a preposition.
        # If we restructure the coordination before attending to the prepositional
        # phrase, we will move the preposition to a lower level and it will be
        # never discovered that it has a PrepArg child.
        $phrase = $self->detect_multi_word_expression($phrase);
        $phrase = $self->detect_stanford_pp($phrase);
        $phrase = $self->detect_prague_copula($phrase); ###!!! Perhaps we should rename this method to detect_copula_head().
        $phrase = $self->detect_name_phrase($phrase);
        $phrase = $self->detect_stanford_coordination($phrase);
    }
    # Return the resulting phrase. It may be different from the input phrase.
    return $phrase;
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::PhraseBuilder::StanfordToUD

=head1 DESCRIPTION

Derived from C<Treex::Core::Phrase::Builder>, this class implements language-
and treebank-specific phrase structures.

It expects that the dependency relation labels have been translated to the
Universal Dependencies dialect. The expected tree structure features Stanford
coordination and prepositional phrases headed by the preposition.
The target style is Universal Dependencies.

Input treebanks for which this builder should work include the Google Universal
Dependency Treebanks version 2.0 (spring 2014).

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
