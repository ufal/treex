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
    my $lexnode = $t_node->wild->{'deepfix_info'}->{'lexnode'};
    
    return if $t_node->formeme !~ /(:1|^drop)$/;
    return if !defined $lexnode;

    {
        my $next_node = $lexnode->get_next_node();
        if ( defined $next_node && $next_node->lemma eq ',') {
            return;
        }

    }

    if ( $self->magic !~ /DropCoord/ ) {
        # We want to drop only subjects that are not coordinated ("he or she")
        return if $t_node->is_member;
    }

    if ( $self->magic !~ /DropRoot/ ) {
        return if $parent->is_root();
    }

    if ( $self->magic =~ /noto/ ) {
        return if $lexnode->form =~ /to/i;
    }

    if ( $lexnode->form =~ /^to$/i ) {
        my $ennode = $t_node->wild->{'deepfix_info'}->{'ennode'};
        my $enlex = defined $ennode ? $ennode->get_lex_anode() : undef;

        # this/that should usually be kept
        if ( defined $enlex && $enlex->form =~ /this|that|these|those/i ) {
            return;
            # TODO and probably make this/that the subject
        }

        if ( $self->magic =~ /no_aligned_to/ ) {
            if ( !defined $enlex ) {
                return;
            }
        }
        if ( $self->magic =~ /no_it_aligned_to/ ) {
            if ( !defined $enlex || $enlex->form !~ /it/i ) {
                return;
            }
        }
        if ( $self->magic =~ /no_this_aligned_to/ ) {
            if ( !defined $enlex || $enlex->form =~ /this/i ) {
                return;
            }
        }
    }

    # As a special case we want to drop word "to" (lemma=ten)
    # when it is a subject of some verb other than "být|znamenat".
    if ( $lemma eq 'ten' && $p_lemma !~ /^(být|znamenat)$/ && $self->magic !~ /noten/ ) {
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
                # TODO this has no effect, why? Maybe depfix ignores the Sb/Obj afun distinction?
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

    my $parent_verb = $self->find_verb($t_pronoun);
    if ( defined $parent_verb
        && $self->get_node_tag_cat($parent_verb, 'POS') eq 'V'
        && $parent_verb->ord > ($pronoun->ord + 1)
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

    return $self->remove_anode($pronoun);
}

sub find_verb {
    my ($self, $t_pronoun) = @_;

    my $result = undef;
    
    # first try to find a parenting verb
    if ( defined $t_pronoun->wild->{'deepfix_info'}->{'parent'} ) {
        my $node = $t_pronoun;
        while ( defined $node->wild->{'deepfix_info'}->{'parent'}) {

            my $parent = $node->wild->{'deepfix_info'}->{'parent'};
            if ( $self->nodes_in_different_clauses($node, $parent) == 1 ) {
                # do not cross clause boundaries
                last;
            }
            elsif ( $parent->formeme =~ /v:.*fin/ ) {
                # we found a (hopefully the) verb
                $result = $parent;
                # $result = $parent->wild->{'deepfix_info'}->{'lexnode'};
                last;
            }
            else {
                # move up to the parent
                $node = $parent;
            }
        }
    }

    # if not successful, try to find a preceding verb
    #if ( !defined $result ) {
    #}

    if ( defined $result ) {
        # find the first verb that is not 'by'
        $result =
        ( first {
                $_->tag =~ /^V[^c]/ && $_->form !~ /^js[emti]*$/i }
            $result->get_anodes( { ordered => 1 } ) )
        // $result->wild->{'deepfix_info'}->{'lexnode'};
    }

    return $result;
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
