package Treex::Block::T2T::CS2CS::DropSubjPersProns;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2T::CS2CS::Deepfix';

sub fix {
    my ( $self, $t_node ) = @_;

    # some shotcuts (the values are precomputed anyway)
    my $parent = $t_node->wild->{'deepfix_info'}->{'parent'};
    my $lemma = $t_node->wild->{'deepfix_info'}->{'tlemma'};
    my $p_lemma = $t_node->wild->{'deepfix_info'}->{'ptlemma'};
    
    return if $t_node->formeme !~ /(:1|^drop)$/;
    
    if ( $self->magic !~ /DropCoord/ ) {
        # We want to drop only subjects that are not coordinated ("he or she")
        return if $t_node->is_member;
    }

    if ( $self->magic !~ /DropRoot/ ) {
        return if $parent->is_root();
    }

    # As a special case we want to drop word "to" (lemma=ten)
    # when it is a subject of some verb other than "být|znamenat".
    if ( $lemma eq 'ten' && $p_lemma !~ /^(být|znamenat)$/ ) {
        my $result = $self->drop($t_node);
        if ( $result ) {
            $self->logfix( "DropSubjPersPron: drop 'to' $result" );
        }
        # find the Object and make it the Subject
        log_info "t parent: " . $parent->t_lemma;
        my $parent_lex = $parent->get_lex_anode();
        if ( defined $parent_lex ) {
            log_info "a parent: " . $parent_lex->form;
            my $first_noun_object =
                first { $_->afun eq 'Obj' && $self->get_node_tag_cat($_, 'POS') eq 'N' }
                $parent_lex->get_echildren( { ordered => 1 } );
            if ( defined $first_noun_object ) {
                log_info "1st obj: " . $first_noun_object->form;
                $self->logfix(
                    "DropSubjPersPron: Obj->Sb "
                    . $self->change_anode_attribute(
                        'afun', 'Sb', $first_noun_object));
            }
        }
    }

    # Now we are interested only in personal pronouns
    return if $lemma ne '#PersPron';

    # In some copula constructions, the word "to" is needed instead of a personal pronoun
    # "He was a man who..." = "Byl to muž, který..."
    if ( $p_lemma eq 'být' ) {
        my $real_subj = first { $_->formeme =~ /:1$/ } $parent->get_children( { following_only => 1 } );
        if ( $real_subj && any { $_->formeme eq 'v:rc' } $real_subj->get_children() ) {
            my $a_node = $t_node->get_lex_anode();
            return if !defined $a_node;
            $a_node->shift_after_node( $a_node->get_parent() );
            $self->logfix(
                $self->change_anode_attributes( {
                    'lemma' => 'ten',
                    'tag:subpos' => 'D',
                    'tag:gender' => 'N',
                    'tag:person' => '-',
                    }, $a_node,
                ));
            return;
        }
    }

    # Oherwise drop the perspron
    my $result = $self->drop($t_node);
    if ( $result ) {
        $self->logfix( "DropSubjPersPron: drop pers pron $result" );
    }

    return;
}

sub drop {
    my ($self, $t_pronoun) = @_;

    my $pronoun = $t_pronoun->wild->{'deepfix_info'}->{'lexnode'};

    return if (!defined $pronoun);

    if ( $self->magic =~ /DropMove/ ) {
        my $parent_verb = $pronoun->get_eparents(
            {first_only => 1, or_topological => 1} );
        if ( $self->get_node_tag_cat($parent_verb, 'POS') eq 'V'
            && $parent_verb->ord != ($pronoun->ord + 1)
        ) {
            # try to shift the verb into the position of the pronoun
            # (loosely obeying the Wackernagel rule)
            my $parent_verb_orig_preceding = $parent_verb->get_prev_node();
            $parent_verb->shift_after_node( $pronoun, { without_children => 1 } );
            # try to fix the spaces
            if (defined $parent_verb_orig_preceding) {
                $parent_verb_orig_preceding->set_no_space_after($parent_verb->no_space_after);
            }
            $parent_verb->set_no_space_after($pronoun->no_space_after);
        }
    }

    return $self->remove_anode($pronoun);
}


1;

__END__

=over

=item Treex::Block::T2A::CS::DropSubjPersProns

Applying pro-drop - deletion of personal pronouns (and "to") in subject positions.
In some copula constructions the personal pronoun subject is replaced with the word "to".

=back

=cut

# Copyright 2008-2012 Zdenek Zabokrtsky, Martin Popel, Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
