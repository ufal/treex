package Treex::Block::T2A::ApplyDeepfixChanges;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

has '+language'      => ( required => 1 );
has 'log_to_console' => ( default  => 0, is => 'ro', isa => 'Bool' );
# has 'to_selector'    => ( required => 1, is => 'ro', isa => 'Str' );
# has 'orig_alignment_type' => ( default  => 'orig', is => 'ro', isa => 'Str' );
# has 'src_alignment_type' => ( default  => 'src', is => 'ro', isa => 'Str' );

use Treex::Tool::Depfix::CS::FormemeSplitter;

# TODO: call on "original nodes"!!!
sub process_tnode {
    my ( $self, $tnode ) = @_;

    # check whether to fix the node
    if ( $tnode->wild->{'deepfix'} ) {
        
        # find the corresponding anode
        my $anode = $tnode->get_lex_anode();
        if ( !defined $anode) {
            log_warn( "T-node " . tnode_sgn($tnode) .  " has no lex node!" );
            return;
        }
        
        # change anode
        if ( $tnode->wild->{'deepfix'}->{'change_node'} ) {
            my $msq = '';
            foreach my $attribute (keys %{$tnode->wild->{'deepfix'}->{'change_node'}}) {
                my $value = $tnode->wild->{'deepfix'}->{'change_node'}->{$attribute}->{'value'};
                $msq .= $self->change_attribute($anode, $attribute, $value);
            }
            # TODO: regenerate node
            $self->logfix('change_anode ' . anode_sgn($anode) . ':' . $msg);
        }
        
        
        # fix the parent
        my $parent = $anode->get_eparents( { first_only => 1, or_topological => 1 } );
        if ( defined $parent ) {
            # change parent
            if ( $tnode->wild->{'deepfix'}->{'change_parent'} ) {
                my $msq = '';
                foreach my $attribute (keys %{$tnode->wild->{'deepfix'}->{'change_node'}}) {
                    my $value = $tnode->wild->{'deepfix'}->{'change_node'}->{$attribute}->{'value'};
                    $msq .= $self->change_attribute($anode, $attribute, $value);
                }
                # TODO: regenerate node
                $self->logfix('change_parent ' . anode_sgn($parent) . ':' . $msg);
            }
    
            # remove parent
            if ( $tnode->wild->{'deepfix'}->{'remove_parent'} ) {
                if (defined $parent->lemma
                    && $parent->lemma eq $tnode->wild->{'deepfix'}->{'remove_parent'}->{'lemma'}
                ) {
                    $self->logfix('remove_parent ' . anode_sgn($parent));
                    $self->remove_node($parent);
                }
                else {
                    log_warn('A-node ' . anode_sgn($anode) . ' parent should be removed, but the lemmas do not match: '
                        . $parent->lemma . ' != ' . $tnode->wild->{'deepfix'}->{'remove_parent'}->{'lemma'} . '!');
                }
            }
        }
        else {
            log_info( 'A-node ' . anode_sgn($anode) .  ' has no parent.' );
            return;
        }

        # add parent
        if ( $tnode->wild->{'deepfix'}->{'add_parent'} ) {
            $self->add_parent($anode, $parent_info);
        }
        
    }

    return;
}

# returns log message on success
# or undef on failure
sub change_attribute {
    my ($self, $node, $attribute, $value) = @_;

    my $msg = " $attribute:";
    if ($attribute =~ /^tag:(.+)$/) {
        my $cat = $1;
        my $tag = $node->tag;
        $msg .= get_tag_cat($tag, $cat) . '->' . $value;
        my $new_tag = set_tag_cat($tag, $cat, $value);
        $node->set_tag($new_tag);
    }
    else {
        $msg .= $node->get_attr($attribute) . '->' . $value;
        $node->set_attr($attribute, $value);
    }

    return $msg;
}

# remove only the given node, moving its children under its parent
sub remove_node {
    my ($node) = @_;

    my $parent   = $node->get_parent();
    my @children = $node->get_children();
    foreach my $child (@children) {
        $child->set_parent($parent);
    }
    $node->remove();

    return;
}

sub add_parent {
    my ($self, $node, $parent_info) = @_;

    my $parent = $node->get_parent();
    $new_parent = $parent->create_child();
    $new_parent->set_parent($parent);
    $new_parent->shift_before_subtree(
        $node, { without_children => 1 }
    );
    foreach my $attribute (keys %$parent_info) {
        $new_parent->set_attr($attribute, $parent_info->{$attribute});
    }

    return ;
}


# SUPPORT METHODS

sub anode_sgn {
    my ($anode) = @_;

    my $sgn = $anode->id . '(' . $anode->lemma . ')'

    return $sqn;
}

sub tnode_sgn {
    my ($tnode) = @_;

    my $sgn = $tnode->id . '(' . $tnode->t_lemma . ')';

    return $sqn;
}

sub get_tag_cat {
    return Treex::Tool::Depfix::CS::TagHandler::get_tag_cat(@_);
}

sub set_tag_cat {
    return Treex::Tool::Depfix::CS::TagHandler::set_tag_cat(@_);
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

=item C<orig_alignment_type>

Type of alignment between the CS t-trees.
Default is C<orig>.
The alignment must lead from this zone to the zone set by C<to_selector>.

=item C<src_alignment_type>

Type of alignment between the cs_Tfix t-tree and the en t-tree.
Default is C<src>.
The alignemt must lead from cs_Tfix to en.

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
