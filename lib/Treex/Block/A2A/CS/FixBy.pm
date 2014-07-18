package Treex::Block::A2A::CS::FixBy;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

# worsens BLEU but performs really well

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    # 'by' preposition being a head of an inflected word

    if ( !$self->en($dep) || !$self->en($dep)->parent() ) {
        return;
    }
    my $aligned_parent = $self->en($dep)->get_eparents(
        { first_only => 1, or_topological => 1 }
    );

    if (
        $d->{tag} =~ /^....[1-7]/
        && $aligned_parent
        && $aligned_parent->form
        && $aligned_parent->form eq 'by'
        && !$self->isName($dep)

        # ord-wise following node approximation
        # (I do not know how to do this better)
        && !$self->isNumber(
            $aligned_parent->get_descendants(
                { following_only => 1, first_only => 1 }
                )
        )
        && !$self->isTimeExpr( $self->en($dep)->lemma )
        )
    {

        # there shouldn't be any other preposition aligned to 'by'
        # so delete it if there is one
        my ( $nodes, $types ) = $aligned_parent->get_aligned_nodes();
        if ( my $node_aligned_to_by = $$nodes[0] ) {
            if ( $node_aligned_to_by->tag =~ /^R/ ) {
                $self->logfix1( $node_aligned_to_by, "By (aligned prep)" );
                $self->remove_node( $node_aligned_to_by, 1 );
                $self->logfix2(undef);

                # now have to regenerate these
                # as they might have been invalidated
                ( $dep, $gov, $d, $g ) = $self->get_pair($dep);

                # it might happen that $dep has no effective parent any more
                # and we have to quit in that case
                return if !$dep;
            }
        }

        # treat only right children
        if ( $dep->ord < $gov->ord ) {
            return;
        }

        # now find the correct case for this situation
        my $original_case = $d->{case};
        my $new_case      = $original_case;
        if ( $g->{tag} =~ /^N/ ) {

            #set dependent case to genitive
            $new_case = 2;
        } elsif ( $g->{tag} =~ /^A/ ) {

            #set dependent case to instrumental
            $new_case = 7;
        } elsif ( $g->{tag} =~ /^V/ ) {

            # if ($g->{tag} =~ /^Vs/) {
            # if ($g->{tag} =~ /^V[fs]/ || grep { $_->afun eq "AuxR" } $gov->get_children) {
            if ($g->{tag} =~ /^Vs/
                || grep { $_->afun eq "AuxR" } $gov->get_children
                )
            {

                #set dependent case to instrumental
                $new_case = 7;

                # this is now NOT the subject
                if ( $dep->afun eq 'Sb' ) {
                    $dep->set_afun('Obj');
                }
            } else {

                # check whether there is passive in EN
                my $en_by_parent = $aligned_parent->get_eparents(
                    {   first_only                      => 1,
                        or_topological                  => 1,
                        ignore_incorrect_tree_structure => 1
                    }
                );
                if ($en_by_parent->tag =~ /^VB[ND]/
                    && grep {
                        $_->lemma eq "be" && $_->afun eq "AuxV"
                    } $en_by_parent->get_children
                    )
                {

                    # passive transformed into active => this IS now the subject
                    $dep->set_afun('Sb');
                }
            }
        }

        if ( $new_case != $original_case ) {

#            $d->{tag} =~ s/^(....)./$1$new_case/;
#            $d->{tag} = $self->try_switch_num($dep, $d->{tag});

            $self->logfix1( $dep, "By" );
            $self->set_node_tag_cat($dep, 'case', $new_case);
            $self->regenerate_node($dep);
            $self->logfix2($dep);
        }

    }
}

1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixBy

=head1 DESCRIPTION

The English preposition 'by' is usually translated into Czech not by a 
preposition but by using a specific case (genitive or instrumental: genitive 
if the parent is a noun, instrumental if the parent is a passive verb or an 
adjective).

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

