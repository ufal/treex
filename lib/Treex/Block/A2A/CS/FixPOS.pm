package Treex::Block::A2A::CS::FixPOS;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

use Treex::Tool::Lexicon::CS;

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

            # "Rossum's robot" mistranslated as "Rossum je robot" (lit. "Rossum is robot")

            # "left child" is the most probable possessor (Rossum)
            my $left_child = $dep->get_prev_node();

            # "right_child" is the most probable possessee (robot)
            my $right_child = $dep->get_children(
                { following_only => 1, first_only => 1 }
            );
            
            # set possessor's case to genitive (2)
            # to simulate possessivity
            # (Rossum -> Rossuma)
            # (TODO maybe use info from EN tree to do that more accurately)
            if ( defined $left_child
                && $self->get_node_tag_cat( $left_child, 'case' ) ne '2'
            ) {

                $self->logfix1( $left_child, "POS genitive" );
                $self->set_node_tag_cat($left_child, 'case', 2);
                $self->regenerate_node($left_child);
                $self->logfix2($left_child);

                # TODO: also swicth cases of dependent n:attr
            }

            # if we know both the possessor and the possessee
            # (Rossum. robot)
            # we can perform the fix in full
            if (defined $left_child && defined $right_child) {

                # the original parent to the possessor will soon be lost
                # but it might be a good parent for the possessee
                # ( X \ Rossum => X \ robot)
                # (TODO maybe use info from EN tree to do that more accurately)
                if (
                    $left_child->parent->id ne $right_child->id
                    && !$left_child->parent->is_descendant_of($right_child)
                    )
                {
                    $self->logfix1( $right_child, "POS rehang" );
                    $right_child->set_parent( $left_child->parent );
                    $self->logfix2($right_child);
                }

                # TODO: if $left_child is n:attr and is a right child,
                # use its parent!
                
                if ( !$right_child->is_descendant_of($left_child) ) {

                    # move last left child under first right child
                    # (the possessor should be a left attribute of the possessee)
                    # Rossum / X -> Rossum / robot
                    $self->logfix1( $left_child, "POS parent" );
                    $left_child->set_parent($right_child);
                    $self->logfix2($left_child);
                    
                    if ( $self->magic =~ /POSadj/) {

                        my $adj_lemma = Treex::Tool::Lexicon::CS::get_poss_adj($left_child->lemma);
                        if ( $left_child->lemma eq 'kuchař' ) {
                            $adj_lemma = 'kuchařův';
                        }
                        if ( defined $adj_lemma ) {
                            # Rossuma robot -> Rossumův robot
                            my $pos_adj_result = $self->pos_adj(
                                $left_child, $right_child, $adj_lemma);
                            if (!$pos_adj_result) {
                                $self->pos_move($left_child, $right_child);
                            }
                        }
                        else {
                            # Rossuma robot -> robot Rossuma
                            $self->pos_move($left_child, $right_child);
                        }
                        

                    } else {
                        # Rossuma robot -> robot Rossuma
                        $self->pos_move($left_child, $right_child);
                    }
                }
            }

            # remove the node
            # je -> x
            $self->logfix1( $dep, "POS remove" );
            $self->remove_node($dep);
            $self->logfix2(undef);
        }
    }
}

# Rossuma robot -> robot Rossuma
sub pos_move {
    my ($self, $left_child, $right_child) = @_;

    $self->logfix1( $left_child, "POS move" );
    $left_child->set_parent($right_child);

    # do not move nonprojective nodes
    my @nonprojdescs = grep {$_->is_nonprojective} $left_child->get_descendants();
    foreach my $desc (@nonprojdescs) {
        $desc->set_parent($left_child->parent);
    }
    
    $self->shift_subtree_after_node(
        $left_child, $right_child
    );
    $self->logfix2($left_child);

    return ;
}

# Rossuma robot -> Rossumův robot
sub pos_adj {
    my ($self, $left_child, $right_child, $adj_lemma) = @_;

    log_info "POSlemma: $adj_lemma";
    $self->logfix1( $left_child, "POS adj" );
    $left_child->set_lemma($adj_lemma);

    # possessive adjective
    $self->set_node_tag_cat($left_child, 'POS', 'A');
    $self->set_node_tag_cat($left_child, 'subpos', 'U');
    $self->set_node_tag_cat($left_child, 'neg', '-');

    # gender kept in possessive gender (TODO do properly)
    $self->set_node_tag_cat($left_child, 'posgen',
        $self->get_node_tag_cat($left_child, 'gen'));

    # agreement with possessee
    if ( $adj_lemma eq 'kuchařův' ) {
    $self->set_node_tag_cat($left_child, 'gender', 'F');
    $self->set_node_tag_cat($left_child, 'number', 'P');
    $self->set_node_tag_cat($left_child, 'case', '6');
    }
    else {
    $self->set_node_tag_cat($left_child, 'gender',
        $self->get_node_tag_cat($right_child, 'gender'));
    $self->set_node_tag_cat($left_child, 'number',
        $self->get_node_tag_cat($right_child, 'number'));
    $self->set_node_tag_cat($left_child, 'case',
        $self->get_node_tag_cat($right_child, 'case'));
    }

    my $new_form = $self->regenerate_node($left_child);
    if ( defined $new_form ) {
        $self->logfix2($left_child);
        return 1;
    }
    else {
        return 0;
    }
}


1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixPOS

=head1 DESCRIPTION

English possessive "'s" is sometimes mistranslated as if it were "is" ("být"). 
E.g. "Rossum's robot" might be incorrectly translated as "Rossum je robot"
(lit. "Rossum is robot") instead of the correct "Rossumův robot",
or "robot Rossuma" (lit. "robot of Rossum").

This block attempts to detect that -- by checking that either "být" is aligned 
to an English possessive ending, or that the word preceding "být" is aligned 
to a node whose first right child is a possessive ending.
The possessive ending itself is disambiguated using the assigned tag
(which is usually correct).

The fix itself consists of several steps:

=over

=item possessiveness

the probable possessor (the word preceding "být")'s case is changed to genitive
("Rossum" -> "Rossuma")

=item possessor rehanging

the probably possessor is rehung under the probable possessee
(the first right child of "být")
("Rossuma" / "je"; "je" \ "robot" -> "Rossuma" / "robot"; "je" \ "robot")

=item "být" deletion

the extra word "být" is deleted
("Rossuma je robot" -> "Rossuma robot")

=item possessive adjective

an attempt to change the possessor into an possessive adjective is made
("Rossuma robot" -> "Rossumův robot")

=item or move

if the possessive adjective cannot be generated,
the possessor is moved after the possessee
("Rossuma robot" -> "robot Rossuma")

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
