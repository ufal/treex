package Treex::Block::Filter::RemoveEmptySentences;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_document
{
    my $self = shift;
    my $document = shift;
    my @bundles = $document->get_bundles();
    for(my $i = 0; $i<=$#bundles; $i++)
    {
        # Examine the user-defined zone (language + selector) for empty tokens.
        # Ignore the other zones, if any (but remove them too, if an empty sentence is detected).
        my $zone = $bundles[$i]->get_zone($self->language(), $self->selector());
        log_fatal('Zone '.$self->language().' '.$self->selector().' not found.') if(!defined($zone));
        my $root = $zone->get_atree();
        my @nodes = $root->descendants();
        my @nonempty = grep {my $f = $_->form(); defined($f) && $f ne '' && $f ne '_'} (@nodes);
        if(scalar(@nonempty)==0)
        {
            $bundles[$i]->remove();
        }
    }
    return 1;
}

1;

=for Pod::Coverage BUILD set_attr get_attr

=encoding utf-8

=head1 NAME

Treex::Block::Filter::RemoveEmptySentences

=head1 DESCRIPTION

In each bundle, the a-tree in the zone determined by the C<language> and C<selector> parameters
is examined (all other trees and zones are ignored). The tree is considered empty if it either
has no nodes other than the root, or all nodes have undefined or empty C<form>. A form consisting
solely of one underscore character is also considered empty (like in the CoNLL file formats).
If an empty tree is found, the whole bundle is removed from the document (including any other
trees and zones, even if they are not empty).

For instance, the AnCora corpora of Catalan and Spanish from the CoNLL 2009 shared task contain
several sentences that consist of multiple empty nodes.

Known issues:

The current version will not update attributes of the document
(the text of the whole document will no longer correspond to the bundles).

Note that document (file) boundaries are not changed by this block.
We may get an empty document if all sentences are empty, but the document will not be removed.

=back

=head1 AUTHORS

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
