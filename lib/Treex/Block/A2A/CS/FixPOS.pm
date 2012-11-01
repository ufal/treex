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
            # my $left_child  = $dep->get_children( { preceding_only => 1, last_only  => 1 } );
            my $left_child = $dep->get_prev_node();
            if ( defined $left_child && defined $left_child->tag ) {
                my $tag = $left_child->tag;

                # if case (4th position, 1 char) is not 2
                if ( substr( $tag, 4, 1 ) ne '2' ) {

                    # set the case to 2
                    substr $tag, 4, 1, 2;
                    $tag = $self->try_switch_num( $left_child, $tag );

                    # do the fix
                    $self->logfix1( $left_child, "POSgen" );
                    $self->regenerate_node( $left_child, $tag );
                    $self->logfix2($left_child);
                }
            }

            # move last left child under first right child
            # (the possessor should be a left attribute of the possessee)
            # (TODO maybe use info from EN tree to do that more accurately)
            my $right_child = $dep->get_children( { following_only => 1, first_only => 1 } );
            if (   defined $left_child
                && defined $right_child
                && !$right_child->is_descendant_of($left_child)
                )
            {

                # TODO if is descendant, switch somehow...?
                $self->logfix1( $left_child, "POSmov" );
                $left_child->set_parent($right_child);
                # $left_child->shift_after_node($right_child);
                $self->logfix2($left_child);
            }

            # remove the node
            $self->logfix1( $dep, "POSrem" );
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

TODO: check if there is a TectoMT block doing that in a more clever way...

TODO: probably do this on t-layer to be able to also fix n:attr

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
