package Treex::Block::A2A::CS::FixNounClusters;
use Moose;
use Treex::Core::Common;
use Treex::Core::Node::A;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    my $en_dep = $self->en($dep);
    my $en_gov;
    if ($en_dep) {
        $en_gov = $en_dep->get_eparents(
            {
                first_only     => 1,
                or_topological => 1
            }
        );
    }

    #        && !$self->isName($gov)
    if ($d->{pos} eq 'N'
        && !$self->isName($dep)
        && $dep->form ne '%'
        && $g->{pos}  ne 'C'
        && $en_dep
        && $en_dep->tag =~ /^N/
        && $en_gov
        && $en_gov->tag =~ /^N/
        )
    {

        my ($nodes) = $en_gov->get_directed_aligned_nodes();
        if ( !$nodes || !@$nodes ) { return; }

        my $cs_gov = $nodes->[0];
        if ($dep->ord < $cs_gov->ord
            && $cs_gov->tag =~ /^N/
            && !$self->isName($cs_gov)
            )
        {

            # this is probably a noun cluster

            # avoid a cycle in the tree
            if ( $cs_gov->is_descendant_of($dep) ) {
                return;
            }

            # coordination (the whole coordination has to be moved)
            if ( $dep->is_member ) {

                # if is member
                # TODO: maybe move whole coordination, maybe only sometimes...
                return;
            }

            # get important nodes
            my @dep_descendants = $dep->get_descendants(
                {
                    ordered  => 1,
                    add_self => 1
                }
            );
            my ($dep_leftmost_descendant) = @dep_descendants;
            my $dep_subtree_precedent = $dep_leftmost_descendant
                ->get_prev_node();
            my $dep_rightmost_descendant = pop @dep_descendants;

            # beginning of sentence capitalization
            if ( $dep_leftmost_descendant->ord == 1 ) {

                # if is at beginning of sentence
                # TODO: (maybe) guess correct capitalization using a NER
                # BETTER: guess using EN
                return;
            }

            # space normalization
            # move no_space_after values
            my $nsa_dep_rightmost_descendant
                = $cs_gov->no_space_after;
            my $nsa_dep_subtree_precedent
                = $dep_rightmost_descendant->no_space_after;
            my $nsa_cs_gov
                = 0;
            if ( defined $dep_subtree_precedent ) {
                $nsa_cs_gov = $dep_subtree_precedent->no_space_after;
            }

            # assign no_space_after values
            $dep_rightmost_descendant->{'no_space_after'}
                = $nsa_dep_rightmost_descendant;
            $dep_subtree_precedent->{'no_space_after'}
                = $nsa_dep_subtree_precedent;
            if ( defined $dep_subtree_precedent ) {
                $cs_gov->{'no_space_after'} = $nsa_cs_gov;
            }

            $self->logfix1( $dep, "NounClusters" );

            # rehanging
            $dep->set_parent($cs_gov);

            # change ords
            $dep->shift_after_node($cs_gov);

            # change case to genitive
            substr $d->{tag}, 4, 1, '2';

            # my $tag = $self->try_switch_num($dep, $d->{tag});
            $self->regenerate_node( $dep, $d->{tag} );

            $self->logfix2($dep);
        }
    }
}

1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixNounClusters - move noun forming a noun cluster
after its head noun.

=head1 DESCRIPTION

In English, noun clusters are common, e.g. "State Treasury project" or "next
year's budget". In Czech this is not correct: you either have to transform the
modifier nouns into adjectives (which is hard to do in depfix), or you have to
form a genitival structure, e.g. "project of State Treasury" or "budget of
next year", which is exactly what this block does (the case is set to '2',
which stands for genitive).

TODO:
The block now does reasonably well in detecting noun clusters.
However, they should be preferably corrected not by forming a genitival
construction, but by converting the dependent noun into an adjective.
Sadly, I am now not able to do that...

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
