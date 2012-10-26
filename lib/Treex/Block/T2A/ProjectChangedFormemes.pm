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

# use Treex::Block::T2T::CS2CS::FixInfrequentFormemes qw(splitFormeme);
# returns ($pos, \@preps, $case)
sub splitFormeme {
    my ($formeme) = @_;

    # n:
    # n:2
    # n:attr
    # n:v+6

    # defaults
    my $pos  = $formeme;
    my $prep = '';
    my $case = '';         # 1-7, X, attr, poss

    if ( $formeme =~ /^([a-z]+):(.*)$/ ) {
        $pos  = $1;
        $case = $2;
        if ( $case =~ /^(.*)\+(.*)$/ ) {
            $prep = $1;
            $case = $2;
        }
    }

    my @preps = split /_/, $prep;

    return ( $pos, \@preps, $case );
}

sub process_tnode {
    my ( $self, $fixed_tnode ) = @_;

    if ( $fixed_tnode->wild->{'change_by_deepfix'} ) {

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
	
	# if ( $fixed_tnode->formeme ne $orig_tnode->formeme ) {
        $self->logfix(
            $orig_tnode->id
	    . ' trying to change formeme ' . $orig_tnode->formeme
	    . ' to formeme ' . $fixed_tnode->formeme
	    );
        my $aux_fixed = $self->project_aux_nodes( $fixed_tnode, $orig_tnode );
        if ($aux_fixed) {
            $self->project_lex_nodes( $fixed_tnode, $orig_tnode );
        }
    }

    return;
}

# returns 1 if the projection was successfully completed
# returns 0 if the nodes cannot be projected reliably
sub project_aux_nodes {
    my ( $self, $fixed_tnode, $orig_tnode ) = @_;

    my ( undef, $fixed_preps, undef ) = splitFormeme( $fixed_tnode->formeme );
    my $fixed_preps_count = scalar(@$fixed_preps);
    my ( undef, $orig_preps, undef ) = splitFormeme( $orig_tnode->formeme );
    my $orig_preps_count = scalar(@$orig_preps);

    if ( $fixed_preps_count == 0 && $orig_preps_count == 0 ) {

        # there are no prepositions contained in the formeme,
        # therefore there are no aux nodes to be fixed
        $self->logfix("There are no aux nodes to be fixed.");
        return 1;
    }
    elsif ( $fixed_preps_count > 1 || $orig_preps_count > 1 ) {

        # there is more than one part to the preposition,
        # do not fix (maybe only temporary)
        $self->logfix("Skipping the fix, found a multipart preposition formeme.");
        return 0;
    }
    else {

        # there are some prepositions but not more than 1 for each node
        # => we will try to do the aux projection

        my $fixed_prep_anode =
            find_preposition_node( $fixed_tnode, $fixed_preps->[0] );
        my $orig_prep_anode =
            find_preposition_node( $orig_tnode, $orig_preps->[0] );

        if ( $fixed_preps_count == 0 ) {

            # there shouldn't be a prepositon in the tree
            # try to delete the original prep
            if ( defined $orig_prep_anode ) {
                $self->logfix( "AUX: removing preposition " . $orig_prep_anode->form );
                remove_node($orig_prep_anode);

		return 1;
                # TODO remove from aux nodes
            }
            else {
                log_warn("The original preposition was not found in the T tree.");
                return 0;
            }
        }
        else {

            # there should be a prepositon in the tree
            if ( defined $fixed_prep_anode ) {

                # insert a new preposition node if there is none yet
                my $msg = "AUX: ";
                if ( !defined $orig_prep_anode ) {
                    $orig_prep_anode =
                        new_parent_to_node( $orig_tnode->get_lex_anode() );
                    $orig_prep_anode->shift_before_subtree(
                        $orig_tnode->get_lex_anode(), { without_children => 1 }
                    );

                    # TODO add to aux nodes
                    $msg .= "adding a new preposition ";
                }
                else {
                    $msg .= "changing preposition ";
                    $msg .= $orig_prep_anode->form;
                    $msg .= " to preposition ";
                }
                $msg .= $fixed_prep_anode->form;
                $self->logfix($msg);

                # copy morphological information from fixed to orig
                $orig_prep_anode->set_form( $fixed_prep_anode->form );
                $orig_prep_anode->set_lemma( $fixed_prep_anode->lemma );
                $orig_prep_anode->set_tag( $fixed_prep_anode->tag );

		return 1;
            }
            else {
                log_warn("The fixed preposition was not found in the T tree.");
                return 0;
            }
        }

    }

    log_fatal("this line of code should be unreachable");
}

sub find_preposition_node {
    my ( $tnode, $prep_form ) = @_;

    my $prep_node = undef;

    if ( defined $prep_form ) {
        my $lex_anode = $tnode->get_lex_anode();
        if ( defined $lex_anode ) {
            my @matching_aux_nodes = grep {
                lc( $_->form ) =~ /^${prep_form}e?$/
            } $tnode->get_aux_anodes();

            #            # searching in eparents and egrandparents
            #            my @matching_eparents = grep {$_->form eq $prep_form} ($lex_anode->get_eparents(), $lex_anode->get_parent()->get_eparents());

            if ( @matching_aux_nodes == 1 ) {
                $prep_node = $matching_aux_nodes[0];
            }
            else {
                if ( @matching_aux_nodes == 0 ) {
                    log_warn("There is no matching aux node!");
                }
                else {
                    log_warn("There are more than one matching aux nodes!");
                }
            }
        }
        else {
            log_warn( "There is no lex node to the t-node " . $tnode->t_lemma . "!" );
        }
    }

    # else no prep can be found, which this is often a valid result

    return $prep_node;
}

# remove only the given node, moving its children under its parent
sub remove_node {
    my ($node) = @_;

    my $parent   = $node->get_parent();
    my @children = $node->get_children();
    foreach my $child (@children) {
        $child->set_parent($parent);

        # TODO: copy is_member?
    }
    $node->remove();

    return;
}

# create a new node between the given node and its parent
sub new_parent_to_node {
    my ($child) = @_;

    my $parent   = $child->get_parent();
    my $new_node = $parent->create_child();
    $child->set_parent($new_node);

    # TODO: do something about is_member etc.?

    return $new_node;
}

sub project_lex_nodes {
    my ( $self, $fixed_tnode, $orig_tnode ) = @_;

    # get anodes
    my $fixed_anode = $fixed_tnode->get_lex_anode();
    my $orig_anode  = $orig_tnode->get_lex_anode();

    if ( !defined $orig_anode ) {
        log_warn( "T-node " . $orig_tnode->t_lemma . " has no lex node!" );
        return;
    }

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
