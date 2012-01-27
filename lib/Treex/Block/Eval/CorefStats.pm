package Treex::Block::Eval::CorefStats;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ($self, $tnode) = @_;

    if (defined $tnode->t_lemma && ($tnode->t_lemma eq "#PersPron")) {
        my @chain = $tnode->get_coref_chain;
        my $tree = $tnode->get_root;
        print "CHAIN_SIZE: " . @chain . ", SENT_ORD: " . $tree->wild->{"czeng_sentord"} . "\n";
    }
}

1;

=over

=item Treex::Block::Eval::CorefStats

Prints out some of the statistics regarding coreference.

=back

=cut

# Copyright 2011 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
