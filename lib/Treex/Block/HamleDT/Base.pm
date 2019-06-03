package Treex::Block::HamleDT::Base;
use utf8;
use Moose;
use Treex::Core::Common;
use Lingua::Interset qw(decode encode);
extends 'Treex::Core::Block';



#------------------------------------------------------------------------------
# Writes the current sentence including the sentence number to the log. To be
# used together with warnings so that the problematic sentence can be localized
# and examined in Ttred.
#------------------------------------------------------------------------------
sub log_sentence
{
    my $self = shift;
    my $node = shift;
    my $root = $node->get_root();

    # get_position() returns numbers from 0 but Tred numbers sentences from 1.
    my $i = $root->get_bundle()->get_position() + 1;
    my $sentence = $root->get_zone()->sentence() // '';
    log_warn( "\#$i $sentence" );
}



#------------------------------------------------------------------------------
# Returns 1 if the sentence of a given node contains a given substring (mind
# tokenization). Returns 0 otherwise. Can be used to easily focus debugging on
# a problematic sentence like this:
# $debug = $self->sentence_contains($node, 'sondern auch mit Instrumenten');
#------------------------------------------------------------------------------
sub sentence_contains
{
    my $self     = shift;
    my $node     = shift;
    my $query    = shift;
    my $sentence = $node->get_zone()->sentence();
    return $sentence =~ m/$query/;
}



#------------------------------------------------------------------------------
# Collects all nodes in a subtree of a given node. Useful for fixing known
# annotation errors, see also get_node_spanstring(). Returns ordered list.
#------------------------------------------------------------------------------
sub get_node_subtree
{
    my $self = shift;
    my $node = shift;
    my @nodes = $node->get_descendants({'add_self' => 1, 'ordered' => 1});
    return @nodes;
}



#------------------------------------------------------------------------------
# Collects word forms of all nodes in a subtree of a given node. Useful to
# uniquely identify sentences or their parts that are known to contain
# annotation errors. (We do not want to use node IDs because they are not fixed
# enough in all treebanks.) Example usage:
# if($self->get_node_spanstring($node) =~ m/^peça a URV em a sua mesada$/)
#------------------------------------------------------------------------------
sub get_node_spanstring
{
    my $self = shift;
    my $node = shift;
    my @nodes = $self->get_node_subtree($node);
    return join(' ', map {$_->form() // ''} (@nodes));
}



1;

=over

=item Treex::Block::HamleDT::Base

This block itself does not do anything but it provides some methods that may
be useful in the derived transformation blocks.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2019 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
