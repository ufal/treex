package Treex::Tool::PhraseBuilder::ToUD;

use utf8;
use namespace::autoclean;

use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Log;

extends 'Treex::Tool::PhraseBuilder::BasePhraseBuilder';



#------------------------------------------------------------------------------
# Defines the dialect of the labels used in Universal Dependencies (Stanford).
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
        'apos'   => ['^apos$', 'apos'],   # head of paratactic apposition (punctuation or conjunction)
        'appos'  => ['^appos$', 'appos'], # dependent member of hypotactic apposition
        'auxg'   => ['^punct$', 'punct'], # punctuation other than comma
        'auxk'   => ['^punct$', 'punct'], # sentence-terminating punctuation
        'auxpc'  => ['^case|mark$'],      # adposition or subordinating conjunction
        'auxp'   => ['^case$', 'case'],   # adposition
        'auxc'   => ['^mark$', 'mark'],   # subordinating conjunction
        'psarg'  => ['^(adp|sc)arg$'],  # argument of adposition or subordinating conjunction
        'parg'   => ['^adparg$', 'adparg'], # argument of adposition
        'sarg'   => ['^scarg$', 'scarg'], # argument of subordinating conjunction
        'auxx'   => ['^punct$', 'punct'], # comma
        'auxy'   => ['^cc$', 'cc'],       # additional coordinating conjunction or other function word
        'auxyz'  => ['^aux[yz]$'],
        'cc'     => ['^cc$', 'cc'],       # coordinating conjunction
        'conj'   => ['^conj$', 'conj'],   # conjunct
        'coord'  => ['^coord$'],          # head of coordination (conjunction or punctuation)
        'mwe'    => ['^mwe$', 'mwe'],     # non-head word of a multi-word expression; PDT has only multi-word prepositions
        'punct'  => ['^punct$', 'punct'],
        'det'    => ['^det$', 'det'],       # determiner attached to noun
        'detarg' => ['^detarg$', 'detarg'], # noun attached to determiner
        'nummod' => ['^nummod$', 'nummod'], # numeral attached to counted noun
        'numarg' => ['^numarg$', 'numarg'], # counted noun attached to numeral
        'amod'   => ['^amod$', 'amod'],     # adjective attached to noun
        'adjarg' => ['^adjarg$', 'adjarg'], # noun attached to adjective that modifies it
        'genmod' => ['^nmod$', 'nmod'],     # genitive or possessive noun attached to the modified (possessed) noun
        'genarg' => ['^genarg$', 'genarg'], # possessed (modified) noun attached to possessive (genitive) noun that modifies it
        'pnom'   => ['^pnom$', 'pnom'],     # nominal predicate (predicative adjective or noun) attached to a copula
        'cop'    => ['^cop$', 'cop'],       # copula attached to a nominal predicate
        'subj'   => ['subj'],
        'nsubj'  => ['^nsubj$', 'nsubj'],
        'nmod'   => ['^nmod$', 'nmod'],
        'advmod' => ['^advmod$', 'advmod'],
    );
    return \%map;
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::PhraseBuilder::ToUD

=head1 DESCRIPTION

Derived from C<Treex::Core::Phrase::Builder>, this class implements language-
and treebank-specific phrase structures.

This class defines the UD dialect of dependency relation labels, including
some labels that are actually not used in UD but may be needed during the
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
