package Treex::Tool::PhraseBuilder::ToPrague;

use utf8;
use namespace::autoclean;

use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Log;

extends 'Treex::Tool::PhraseBuilder::BasePhraseBuilder';



#------------------------------------------------------------------------------
# Defines the dialect of the Prague annotation style that is used in the data.
# What dependency labels are used? By separating the labels from the other code
# we can share some transformation methods that are useful for multiple target
# styles.
#------------------------------------------------------------------------------
sub _build_dialect
{
    # A lazy builder can be called from anywhere, including map or grep. Protect $_!
    local $_;
    # Mapping from id to regular expression describing corresponding deprels in the dialect.
    # The second position is the label used in set_deprel(); not available for all ids.
    my %map =
    (
        'apos'   => ['^Apos$', 'Apos'],  # head of paratactic apposition (punctuation or conjunction)
        'appos'  => ['^Apposition$', 'Apposition'], # dependent member of hypotactic apposition
        'auxg'   => ['^AuxG$', 'AuxG'],  # punctuation other than comma
        'auxk'   => ['^AuxK$', 'AuxK'],  # sentence-terminating punctuation
        'auxpc'  => ['^Aux[PC]$'],       # preposition or subordinating conjunction
        'auxp'   => ['^AuxP$', 'AuxP'],  # preposition
        'auxc'   => ['^AuxC$', 'AuxC'],  # subordinating conjunction
        'psarg'  => ['^(Prep|Sub)Arg$'], # argument of preposition or subordinating conjunction
        'parg'   => ['^PrepArg$', 'PrepArg'], # argument of preposition
        'sarg'   => ['^SubArg$', 'SubArg'], # argument of subordinating conjunction
        'auxx'   => ['^AuxX$', 'AuxX'],  # comma
        'auxy'   => ['^AuxY$', 'AuxY'],  # additional coordinating conjunction or other function word
        'auxyz'  => ['^Aux[YZ]$'],
        'cc'     => ['^AuxY$', 'AuxY'],  # coordinating conjunction
        'conj'   => ['^CoordArg$', 'CoordArg'], # conjunct
        'coord'  => ['^Coord$'],         # head of coordination (conjunction or punctuation)
        'mwe'    => ['^AuxP$', 'AuxP'],  # non-head word of a multi-word expression; PDT has only multi-word prepositions
        'punct'  => ['^Aux[XGK]$', 'AuxG'],
        'det'    => ['^AuxA$', 'AuxA'],       # determiner attached to noun
        'detarg' => ['^DetArg$', 'DetArg'],   # noun attached to determiner
        'nummod' => ['^Atr$', 'Atr'],         # numeral attached to counted noun
        'numarg' => ['^NumArg$', 'NumArg'],   # counted noun attached to numeral
        'amod'   => ['^Atr$', 'Atr'],         # adjective attached to noun
        'adjarg' => ['^AdjArg$', 'AdjArg'],   # noun attached to adjective that modifies it
        'genmod' => ['^Atr$', 'Atr'],         # genitive or possessive noun attached to the modified (possessed) noun
        'genarg' => ['^PossArg$', 'PossArg'], # possessed (modified) noun attached to possessive (genitive) noun that modifies it
        'pnom'   => ['^Pnom$', 'Pnom'],       # nominal predicate (predicative adjective or noun) attached to a copula
        'cop'    => ['^Cop$', 'Cop'],         # copula attached to a nominal predicate
        'subj'   => ['^Sb$'],
        'nsubj'  => ['^Sb$', 'Sb'],
        'nmod'   => ['^Atr|Adv$', 'Adv'],
        'advmod' => ['^Adv$', 'Adv'],
        'name'   => ['^Atr$', 'Atr'],
    );
    return \%map;
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::PhraseBuilder::ToPrague

=head1 DESCRIPTION

Derived from C<Treex::Core::Phrase::Builder>, this class implements language-
and treebank-specific phrase structures.

This class defines the Prague dialect of dependency relation labels, including
some labels that are actually not used in Prague Dependencies but may be needed during the
conversion to denote relations that will later be transformed.

It is assumed that any conversion process begins with translating the deprels
to something close to the target label set. Then the subtrees are identified
whose internal structure does not adhere to the target annotation style. These
are transformed (restructured). Labels that are not valid in the target label
set will disappear during the transformation.

This class may also define transformations specific to the target annotation
style. They may or may not depend on a particular source style. Classes
derived from this class will be designed for concrete source-target pairs
and will select which transformations shall be actually performed.

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
