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



#------------------------------------------------------------------------------
# Examines a nonterminal phrase in the Prague style. If it recognizes
# a prepositional phrase, transforms the general nonterminal to PP.
#------------------------------------------------------------------------------
sub detect_prague_pp
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase::NTerm
    # If this is the Prague style then the preposition (if any) must be the head and the deprel of the phrase must be AuxP.
    if($phrase->deprel() eq 'AuxP')
    {
        my @dependents = $phrase->dependents();
        my @mwauxp;
        my @punc;
        my @candidates;
        # Classify dependents of the preposition.
        foreach my $d (@dependents)
        {
            # AuxP attached to AuxP means multi-word preposition.
            ###!!! We should also check that all words of a MWE are adjacent!
            if($d->deprel() eq 'AuxP')
            {
                push(@mwauxp, $d);
            }
            # Punctuation should never represent an argument of a preposition (provided we have solved any coordinations on lower levels).
            elsif($d->node()->is_punctuation())
            {
                push(@punc, $d);
            }
            # All other dependents are candidates for the argument.
            else
            {
                push(@candidates, $d);
            }
        }
        # If there are no argument candidates, we cannot create a prepositional phrase.
        my $n = scalar(@candidates);
        if($n == 0)
        {
            return $phrase;
        }
        # Now it is clear that we have a prepositional phrase. A new PP will be created
        # and the old input NTerm will be destroyed.
        my $preposition = $phrase->head();
        # If there are two or more argument candidates, we have to select the best one.
        # There may be more sophisticated approaches but let's just take the first one for the moment.
        ###!!! We should make sure that we have an ordered list and that we know whether we expect prepositions or postpositions.
        ###!!! Then we should pick the first candidate after (resp. before) the preposition (resp. postposition).
        my $argument = shift(@candidates);
        my $parent = $phrase->parent();
        $phrase->detach_children_and_die();
        # If the preposition consists of multiple nodes, group them in a new NTerm first.
        # The main prepositional node has already been detached from its original parent so it can be used as the head elsewhere.
        if(scalar(@mwauxp) > 0)
        {
           $preposition = new Treex::Core::Phrase::NTerm('head' => $preposition);
           foreach my $mwp (@mwauxp)
           {
               $mwp->set_parent($preposition);
           }
        }
        my $pp = new Treex::Core::Phrase::PP('prep' => $preposition, 'arg' => $argument, 'prep_is_head' => 1);
        foreach my $d (@candidates, @punc)
        {
            $d->set_parent($pp);
        }
        $parent->replace_child($phrase, $pp);
        return $pp;
    }
    # Return the input NTerm phrase if no PP has been detected.
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
