package Treex::Core::Phrase::Builder;

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



#------------------------------------------------------------------------------
# Wraps a node (and its subtree, if any) in a phrase.
#------------------------------------------------------------------------------
sub build
{
    my $self = shift;
    my $node = shift; # Treex::Core::Node
    my @nchildren = $node->children();
    my $phrase = Treex::Core::Phrase::Term->new('node' => $node);
    if(@nchildren)
    {
        # Move the is_member flag to the parent phrase.
        my $member = $phrase->is_member();
        $phrase->set_is_member(0);
        # Create a new nonterminal phrase and make the current terminal phrase its head child.
        $phrase = Treex::Core::Phrase::NTerm->new('head' => $phrase, 'is_member' => $member);
        foreach my $nchild (@nchildren)
        {
            my $pchild = $self->build($nchild);
            $pchild->set_parent($phrase);
        }
    }
    # Now look at the new phrase whether it corresponds to any special construction.
    # This may include tree transformations and even construction of a new nonterminal of a special
    # class (we will get the new phrase as the result and the old one will be discarded).
    # We can only inspect and modify the current phrase and its children.
    # Nevertheless, we still have to include terminal phrases because we may have to change their deprels.
    $phrase = $self->detect_special_constructions($phrase);
    return $phrase;
}



#------------------------------------------------------------------------------
# Examines a nonterminal phrase and tries to recognize certain special phrase
# types. This part will be different for different builders. It depends both on
# the expected input style and the desired output style. This method is always
# called after a new nonterminal phrase is built. It can be defined as empty if
# the builder does not do anything special.
#------------------------------------------------------------------------------
sub detect_special_constructions
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # Do the treebank-specific manipulations here.
    # Return the resulting phrase. It may be different from the input phrase.
    return $phrase;
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Core::Phrase::Builder

=head1 DESCRIPTION

A C<Builder> provides methods to construct a phrase structure tree around
a dependency tree. It takes a C<Node> and returns a C<Phrase>.

The tree of phrases is constructed bottom-up and after every new nonterminal
phrase is created, the method C<detect_special_constructions()> is called.
It is empty by default but derived classes may use it to implement detection
of special phrase types in particular annotation styles, such as the Prague-style
coordination. See C<Treex::Tool::PhraseBuilder> for an example.

=head1 METHODS

=over

=item build

Wraps a node (and its subtree, if any) in a phrase.

=item detect_special_constructions

Takes a phrase and returns either the same phrase, or a new phrase that should
replace it.

Examines a nonterminal phrase and tries to recognize certain special phrase
types. This part will be different for different builders. It depends both on
the expected input style and the desired output style. This method is always
called after a new nonterminal phrase is built. It can be defined as empty if
the builder does not do anything special.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
