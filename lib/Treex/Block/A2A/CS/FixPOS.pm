package Treex::Block::A2A::CS::FixPOS;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    if (
        $dep->lemma eq 'být'
        && $self->en($dep)
        && $self->en($dep)->tag
        && $self->en($dep)->tag eq 'POS'
        )
    {

        $self->logfix1( $dep, "POS" );

        # move last left child under first right child
        # (TODO or use info from EN tree to do that more accurately)
        my $left_child  = $dep->get_children( { preceding_only => 1, last_only  => 1 } );
        my $right_child = $dep->get_children( { following_only => 1, first_only => 1 } );
        if ( $left_child && $right_child ) {
            $left_child->set_parent($right_child);
        }

        # remove the node
        $self->remove_node($dep);

        $self->logfix2($dep);

    }
}

1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixPOS

=head1 DESCRIPTION

English possessive 's is sometimes mistranslated as if it were "is". This 
block attmepts to fix that (provided that the tag on the source side is 
correct). In the first simple implementation, the translation (být) is 
deleted.

TODO: the left child, which is the possessor, should be switched to 
the possessive and hung under the first right child...

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
