package Treex::Block::T2P::CopyTtree;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;

    my $troot = $zone->get_ttree();
    my $proot = $zone->create_ptree();
    # $troot->set_deref_attr( 'ptree.rf', $troot );

    my @tchilds = $troot->get_children();

    if (1 == scalar @tchilds) {
        $proot->set_phrase($tchilds[0]->functor);
        copy_subtree( $tchilds[0], $proot );
    } else {
        $proot->set_phrase("GLUE");
        copy_subtree( $troot, $proot );
        log_warn $troot->id()
            .":Glueing children. Expected 1 child, got "
            .scalar(@tchilds);
    }
}

sub copy_subtree {
    my ( $troot, $proot ) = @_;

    my $my_ord = $troot->ord;
    # create left children nonterminals
    # create head (self) terminal
    # create right children nonterminals
    my $emitted = 0;
    my @children = $troot->get_children( { ordered => 1 } );
    my $tnode;
    while ($tnode = shift(@children) || !$emitted) {
        $tnode = undef if $tnode == 1; # weird get_children returns 1 sometimes
        if (!$emitted && (! defined $tnode || $tnode->ord > $my_ord)) {
            # emit our terminal node
            my $pnode = $proot->create_terminal_child();
            my $lemma = $troot->t_lemma;
            # $lemma =~ s/_s[ie]$//g;
            $pnode->set_lemma($lemma);
            $pnode->set_form($lemma);
            my $tag = $troot->formeme;
            $tag = "---" if !defined $tag;
            $pnode->set_tag($tag);
            $emitted = 1;
            $pnode->add_aligned_node($troot, "T2P::CopyTtree");
        }

        if (defined $tnode) {
            # create child nonterminal
            my $pnode = $proot->create_nonterminal_child();
            $pnode->set_phrase($tnode->functor);
            copy_subtree( $tnode, $pnode );
        }
    }
}

1;

=over

=item Treex::Block::T2P::CopyTtree

This block clones t-tree as an p-tree.
Based on T2A::CopyTtree

=back

=cut

# Copyright 2011 Ondrej Bojar
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
