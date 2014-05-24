package Treex::Block::A2A::RemoveUnannotatedSentences;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'max_nrs' => ( is => 'rw', isa => 'Int', default => 0 );

sub process_atree
{
    my $self = shift;
    my $root = shift;
    my @noafuns = grep {my $afun = $_->afun(); !defined($afun) || $afun eq 'NR'} ($root->get_descendants());
    my $remove = scalar(@noafuns) > $self->max_nrs();
    if($remove)
    {
        log_info('Removing unannotated sentence '.$root->get_address());
        my $bundle = $root->get_bundle();
        $bundle->remove();
    }
}

1;

=over

=item Treex::Block::A2A::RemoveUnannotatedSentences

Some treebanks (especially beta versions and work in progress)
contain sentences that are only partially analyzed or not analyzed at all.
The bad part of the tree is either organized as a chain (every token depends on the previous token)
or all tokens are attached to the root.
The annotation contains few or no syntactic tags (dependency relation labels).

This block identifies all sentences where specified number of non-root nodes lack afun
(it is either undefined or set to C<NR>).
Such sentences are removed from the document.
“Specified number” means more than the C<max_nrs> parameter, default value is 0.
The condition is monitored only in the selected a-tree (language + selector).
If the condition is met however, the whole bundle is removed with all zones.

=back

=cut

# Copyright 2014 Dan Zeman <zeman@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
