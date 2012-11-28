package Treex::Block::A2A::CS::FixPOS;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    if ( $dep->lemma eq 'být' )
    {

        # the corresponding EN node is POS
        my $aligned_is_POS = (
            $self->en($dep)
                && $self->en($dep)->tag
                && $self->en($dep)->tag eq 'POS'
        );

        # the corresponding EN node is not 'be'
        my $aligned_is_not_be = (
            !defined $self->en($dep)
                || !defined $self->en($dep)->lemma
                || $self->en($dep)->lemma ne 'be'
        );

        # the EN node corresponding to the ord-wise preceding node
        # has a child which is POS
        # ($preceding_node defaulting to $dep for simplicity)
        my $preceding_node                     = $dep->get_prev_node() || $dep;
        my $preceding_aligned                  = $self->en($preceding_node);
        my $preceding_is_aligned_to_POS_parent = (
            $preceding_aligned
                && $preceding_aligned->get_children(
                { following_only => 1, first_only => 1 }
                )
                && $preceding_aligned->get_children(
                { following_only => 1, first_only => 1 }
                )->tag
                && $preceding_aligned->get_children(
                { following_only => 1, first_only => 1 }
                )->tag eq 'POS'
        );

        if (
            $aligned_is_POS
            ||
            ( $aligned_is_not_be && $preceding_is_aligned_to_POS_parent )
            )
        {

            # try to switch the case of the last left child to genitive
            # to simulate possessivity
            # (TODO maybe use info from EN tree to do that more accurately)
            my $left_child = $dep->get_prev_node();
            if ( defined $left_child && defined $left_child->tag ) {
                my $tag = $left_child->tag;

                # if case (4th position, 1 char) is not 2
                if ( substr( $tag, 4, 1 ) ne '2' ) {

                    # set the case to 2
                    #substr $tag, 4, 1, 2;
                    #$tag = $self->try_switch_num( $left_child, $tag );

                    # do the fix
                    $self->logfix1( $left_child, "POSgenitive" );
                    $self->set_node_tag_cat($left_child, 'case', 2);
                    $self->regenerate_node($left_child);
                    $self->logfix2($left_child);

                    # TODO: also swicth cases of dependent n:attr
                }
            }

            # move last left child under first right child
            # (the possessor should be a left attribute of the possessee)
            # (TODO maybe use info from EN tree to do that more accurately)
            my $right_child = $dep->get_children(
                { following_only => 1, first_only => 1 }
            );
            if (defined $left_child
                && defined $right_child
                )
            {

                if (
                    $left_child->parent->id ne $right_child->id
                    && !$left_child->parent->is_descendant_of($right_child)
                    )
                {
                    $self->logfix1( $right_child, "POSrehang" );
                    $right_child->set_parent( $left_child->parent );
                    $self->logfix2($right_child);
                }

                # TODO: if $left_child is n:attr and is a right child,
                # use its parent!
                if ( !$right_child->is_descendant_of($left_child) ) {
                    $self->logfix1( $left_child, "POSmove" );
                    $left_child->set_parent($right_child);
                    $self->shift_subtree_after_node(
                        $left_child, $right_child
                    );
                    $self->logfix2($left_child);
                }
            }

            # remove the node
            $self->logfix1( $dep, "POSremove" );
            $self->remove_node($dep);
            $self->logfix2(undef);
        }
    }
}

1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixPOS

=head1 DESCRIPTION

English possessive "'s" is sometimes mistranslated as if it were "is" ("být"). 
This block attempts to detect that -- by checking that either "být" is aligned 
to an English possessive ending, or that the word preceding "být" is aligned 
to a node whose first right child is a possessive ending.
The possessive ending itself is disambiguated using the assigned tag
(which is usually correct).

The fix itself consists of several steps:

=over

=item possessiveness

the probable possessor (the word preceding "být")'s case is changed to genitive

=item possessor rehanging

the probably possessor is rehung under the probable possessee
(the first right child of "být")

=item "být" deletion

the extra word "být" is deleted

=back

TODO: update by adding other fixes performed now

TODO: check if there is a TectoMT block doing that in a more clever way...

TODO: probably do this on t-layer to be able to also fix n:attr
(this is mainly because of people names)

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
