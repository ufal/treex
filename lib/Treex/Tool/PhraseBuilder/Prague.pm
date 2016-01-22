package Treex::Tool::PhraseBuilder::Prague;

use utf8;
use namespace::autoclean;

use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Log;
use Treex::Core::Node;
use Treex::Core::Phrase::Term;
use Treex::Core::Phrase::NTerm;
use Treex::Core::Phrase::PP;
use Treex::Core::Phrase::Coordination;

extends 'Treex::Tool::PhraseBuilder::BasePhraseBuilder';



#------------------------------------------------------------------------------
# Defines the dialect of the Prague annotation style that is used in the data.
# What dependency labels are used? By separating the labels from the other code
# we can use the same PhraseBuilder for Prague-style trees with original Prague
# labels (afuns), as well as for trees in which the labels have already been
# translated to Universal Dependencies (but the topology is still Prague-like).
#
# Usage 0: if ( $self->is_deprel( $deprel, 'punct' ) ) { ... }
# Usage 1: $self->set_deprel( $phrase, 'punct' );
#------------------------------------------------------------------------------
sub _build_dialect
{
    # A lazy builder can be called from anywhere, including map or grep. Protect $_!
    local $_;
    # Mapping from id to regular expression describing corresponding deprels in the dialect.
    # The second position is the label used in set_deprel(); not available for all ids.
    my %map =
    (
        'apos'  => ['^Apos$', 'Apos'], # head of paratactic apposition (punctuation or conjunction)
        'appos' => ['^Apposition$', 'Apposition'], # dependent member of hypotactic apposition
        'auxg'  => ['^AuxG$', 'AuxG'], # punctuation other than comma
        'auxk'  => ['^AuxK$', 'AuxK'], # sentence-terminating punctuation
        'auxpc' => ['^Aux[PC]$'],      # preposition or subordinating conjunction
        'auxx'  => ['^AuxX$', 'AuxX'], # comma
        'auxy'  => ['^AuxY$', 'AuxY'], # additional coordinating conjunction or other function word
        'auxyz' => ['^Aux[YZ]$'],
        'cc'    => ['^AuxY$', 'AuxY'], # coordinating conjunction
        'conj'  => ['^CoordArg$', 'CoordArg'], # conjunct
        'coord' => ['^Coord$'],        # head of coordination (conjunction or punctuation)
        'mwe'   => ['^AuxP$', 'AuxP'],   # non-head word of a multi-word expression; PDT has only multi-word prepositions
        'punct' => ['^Aux[XGK]$', 'AuxG'],
    );
    return \%map;
}



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
        $phrase = $self->detect_prague_pp($phrase);
    }
    # Return the resulting phrase. It may be different from the input phrase.
    return $phrase;
}



#==============================================================================
# Coordination
#==============================================================================



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

=item detect_prague_pp

Examines a nonterminal phrase in the Prague style. If it recognizes
a prepositional phrase, transforms the general nonterminal to PP.
Returns the resulting phrase (if nothing has been changed, returns
the original phrase).

=item detect_prague_coordination

Examines a nonterminal phrase in the Prague style (with analytical functions
converted to dependency relation labels based on Universal Dependencies). If
it recognizes a coordination, transforms the general NTerm to Coordination.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
