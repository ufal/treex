package Treex::Block::Filter::NthSentence;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has n =>
(
    isa           => 'Int',
    is            => 'ro',
    required      => '0',
    default       => '10',
    documentation => 'every n-th bundle will be included or excluded'
);

has keep => (
    isa           => 'Bool',
    is            => 'ro',
    required      => '1',
    documentation => 'true => every n-th bundle will be kept; false => every n-th bundle will be left out'
);

sub process_document
{
    my ( $self, $document ) = @_;
    my @bundles = $document->get_bundles();
    for(my $i = 0; $i<=$#bundles; $i++)
    {
        if(($i+1) % $self->n() == 0)
        {
            # This is the n-th sentence. Keep or discard?
            if(!$self->keep())
            {
                $bundles[$i]->remove();
            }
        }
        else # ($i+1) % $n != 0
        {
            # This is not the n-th sentence. Keep or discard?
            if($self->keep())
            {
                $bundles[$i]->remove();
            }
        }
    }
    return 1;
}

1;

=for Pod::Coverage BUILD set_attr get_attr

=encoding utf-8

=head1 NAME

Treex::Block::Filter::NthSentence

=head1 DESCRIPTION

Either keeps every n-th sentence of the document and discards the rest,
or discards every n-th sentence and keeps the rest.
Useful for evenly splitting a corpus into training and test sets,
especially if different parts of the corpus come from different domains.

Known issues:

The current version will not update attributes of the document
(the text of the whole document will no longer correspond to the bundles).

The sentences are counted from scratch in every document.
If the corpus consists of many very short documents, no n-th sentence may be reached.

Note that document (file) boundaries are not changed by this block.
The resulting files may be comparatively short if C<keep=true>.

=head1 ATTRIBUTES

=over 4

=item n

every C<n>-th sentence is either kept or discarded.
For the purpose of sentence selection, the first sentence of the document
has number 1, not 0.
If C<n=10>, sentences no. 10, 20, 30 etc. will be kept/discarded.
Default C<n> is 10.

=item keep

boolean: shall the C<n>-th sentence be kept (C<true>) or discarded (C<false>)?

=back

=cut

# Copyright © 2011 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
