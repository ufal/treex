package Treex::Tool::PhraseBuilder::Prague;

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
        # level of the tree. For example: We see a phrase labeled Coord (coordination),
        # hence we do not see a prepositional phrase (the label would have to be AuxP
        # instead of Coord). However, after processing the coordination the phrase
        # will get a new label and it may well be AuxP.
        $phrase = $self->detect_prague_coordination($phrase);
        $phrase = $self->detect_prague_apposition($phrase);
        $phrase = $self->detect_punctuation_pnom_apposition($phrase);
        $phrase = $self->detect_prague_pp($phrase);
    }
    # Return the resulting phrase. It may be different from the input phrase.
    return $phrase;
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::PhraseBuilder::Prague

=head1 DESCRIPTION

Derived from C<Treex::Core::Phrase::Builder>, this class implements language-
and treebank-specific phrase structures.

There are methods that detect structures in a Prague-style treebank (such as
the Czech Prague Dependency Treebank).

Transformations organized bottom-up during phrase building are advantageous
because we can rely on that all special structures (such as coordination) on the
lower levels have been detected and treated properly so that we will not
accidentially destroy them.

=head1 METHODS

=over

=item build

Wraps a node (and its subtree, if any) in a phrase.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
