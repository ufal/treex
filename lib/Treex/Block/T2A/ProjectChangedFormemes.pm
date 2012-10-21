package Treex::Block::T2A::ProjectChangedFormemes;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

has '+language'      => ( required => 1 );
has 'to_selector'    => ( required => 1, is => 'ro', isa => 'Str' );
has 'log_to_console' => ( default  => 0, is => 'ro', isa => 'Bool' );
has 'alignment_type' => ( default  => 'copy', is => 'ro', isa => 'Str' );

use Carp;

sub process_tnode {
    my ( $self, $fixed_tnode ) = @_;

    my ($orig_tnode) = $fixed_tnode->get_aligned_nodes_of_type(
        $self->alignment_type
    );
    if ( !defined $orig_tnode ) {
        log_fatal(
                  'The t-node '
                . $fixed_tnode->id
                . ' has no aligned t-node in '
                .
                $self->language . '_' . $self->to_selector
        );
    }

    if ( $fixed_tnode->formeme ne $orig_tnode->formeme ) {
        $self->project_lex_nodes( $fixed_tnode, $orig_tnode );
        $self->project_aux_nodes( $fixed_tnode, $orig_tnode );
    }

    return;
}

sub project_lex_nodes {
    my ( $self, $fixed_tnode, $orig_tnode ) = @_;

    # get anodes
    my $fixed_anode = $fixed_tnode->get_lex_anode();
    my $orig_anode  = $orig_tnode->get_lex_anode();

    # log
    my $logmsg = 'LEX: ' .
        $orig_anode->form . '[' . $orig_anode->tag . '] -> ' .
        $fixed_anode->form . '[' . $fixed_anode->tag . ']';
    $self->logfix($logmsg);

    # fix
    $orig_anode->set_tag( $fixed_anode->tag );
    $orig_anode->set_form( $fixed_anode->form );

    return;
}

sub project_aux_nodes {
    my ( $self, $fixed_tnode, $orig_tnode ) = @_;

    #     remove old aux nodes
    #     $node->remove_aux_anodes(@to_remove)

    #     @aux_anodes = $node->get_aux_anodes()
    #     iteratively create aux nodes that are ancestors of the lex node (i.e. just go up until you stop)
    #     iteratively create aux nodes that are descendants of the lex node (i.e. DFS)
    #     for now, ignore aux nodes that are neither this nor that
    #     my $new_node = $existing_node->create_child({lemma=>'house', tag=>'NN' });

    #     set new nodes to be aux nodes of the tnode
    #     $node->set_aux_anodes(@aux_anodes)

    return;
}

sub logfix {
    my ( $self, $msg ) = @_;

    # log to console
    if ( $self->log_to_console ) {
        log_info($msg);
    }

    return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::T2A::ProjectChangedFormemes - 
project changed formemes from one a-tree to another.
(A Deepfix block.)

=head1 DESCRIPTION

Assume that C<language=cs>, C<selector=Tfix> and C<to_selector=T> (as it is 
currently used in Deepfix).

The block is intended to be used in a setup where C<cs_T> t-tree is generated 
from the C<cs_T> a-tree, C<cs_Tfix> t-tree is a copy of C<cs_T> t-tree with some 
formemes changed, and C<cs_Tfix> a-tree is generated from C<cs_Tfix> t-tree.

The task it solves is to replace subtrees in C<cs_T> a-tree by subtrees from 
C<cs_Tfix> a-tree for each pair of subtrees that both correspond to a t-node with 
a formeme differing between C<cs_T> t-tree and C<cs_Tfix> t-tree.

T-trees in C<cs_T> and C<cs_Tfix> are isomorphic, but some of the formemes might 
differ. For each pair of t-nodes with a differing formeme, the corresponding 
lex and aux nodes must be changed.

First, the form and tag of the lex node in C<cs_T> a-tree (belonging to the C<cs_T> 
t-node) is replaced by the form and tag of the lex node from C<cs_Tfix> a-tree 
(belonging to the C<cs_Tfix> t-node) since there is 1:1 correspondence.

Then, the aux nodes belonging to the C<cs_T> t-node are removed from the C<cs_T> 
a-tree.

And finally, copies of the aux nodes belonging to the C<cs_Tfix> t-node are 
inserted into the C<cs_T> a-tree.

=head1 PARAMETERS

=over

=item C<to_selector>

Selector of zone into which the changes should be projected.
This parameter is required.

=item C<alignment_type>

Type of alignment between the t-trees.
Default is C<copy>.
The alignemt must lead from this zone to the zone set by C<to_selector>.
(This all is true by default if the t-tree in this zone was created with 
L<T2T::CopyTtree>.)

=item C<log_to_console>

Set to C<1> to log details about the changes performed, using C<log_info()>.
Default is C<0>.

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
