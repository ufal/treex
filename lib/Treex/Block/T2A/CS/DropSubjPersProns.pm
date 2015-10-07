package Treex::Block::T2A::CS::DropSubjPersProns;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    return if $t_node->formeme !~ /(:1|^drop)$/;
    return if $t_node->is_member;

    # As a special case we want to drop word "to" (lemma=ten)
    # when it is a subject of some verb other than "být|znamenat".
    my $parent = $t_node->get_parent();
    return if $parent->is_root();
    my $p_lemma = $parent->t_lemma;
    my $lemma   = $t_node->t_lemma;
    if ( $lemma eq 'ten' && $p_lemma !~ /^(být|znamenat)$/ ) {
        drop($t_node);
    }

    # Now we are interested only in personal pronouns
    return if $lemma ne '#PersPron';

    # In some copula constructions, the word "to" is needed instead of a personal pronoun
    # "He was a man who..." = "Byl to muž, který..."
    if ( $p_lemma eq 'být' ) {
        my $real_subj = first { $_->formeme =~ /:1$/ } $parent->get_children( { following_only => 1 } );
        if ( $real_subj && any { $_->formeme eq 'v:rc' } $real_subj->get_children() ) {
            my $a_node = $t_node->get_lex_anode();
            $a_node->set_lemma('ten');
            $a_node->set_attr( 'morphcat/gender', 'N' );
            $a_node->set_attr( 'morphcat/subpos', 'D' );
            $a_node->set_attr( 'morphcat/person', '-' );
            $a_node->shift_after_node( $a_node->get_parent() );
            return;
        }
    }

    # Oherwise drop the perspron
    drop($t_node);
    return;
}

sub drop {
    my ($t_node) = @_;
    my $a_node = $t_node->get_lex_anode();
    if ( not defined $a_node ) {
        log_warn "Node to be pro-dropped should have non-empty a/lex.rf";
        return;
    }

    # delete the a-node
    # rehang PersPron's children (theoretically there should be none, but ...)
    $a_node->remove({children => 'rehang'});
}

1;

__END__

=over

=item Treex::Block::T2A::CS::DropSubjPersProns

Applying pro-drop - deletion of personal pronouns (and "to") in subject positions.
In some copula constructions the personal pronoun subject is replaced with the word "to".

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
