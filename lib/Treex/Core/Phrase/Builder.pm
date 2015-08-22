package Treex::Core::Phrase::Builder;

use utf8;
use namespace::autoclean;

use Moose;
use Treex::Core::Log;
use Treex::Core::Node;
use Treex::Core::Phrase::Term;
use Treex::Core::Phrase::NTerm;



#------------------------------------------------------------------------------
# Wraps a node (and its subtree, if any) in a phrase.
#------------------------------------------------------------------------------
sub build
{
    my $self = shift;
    my $node = shift; # Treex::Core::Node
    my @nchildren = $node->children();
    my $phrase = new Treex::Core::Phrase::Term('node' => $node);
    if(@nchildren)
    {
        # Create a new nonterminal phrase and make the current terminal phrase its head child.
        $phrase = new Treex::Core::Phrase::NTerm('head' => $phrase);
        foreach my $nchild (@nchildren)
        {
            my $pchild = $self->build_phrase($nchild);
            $pchild->set_parent($phrase);
        }
    }
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

=head1 METHODS

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
