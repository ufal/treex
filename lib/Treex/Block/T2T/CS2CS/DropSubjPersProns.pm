package Treex::Block::T2T::CS2CS::DropSubjPersProns;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2T::CS2CS::Deepfix';

sub fix {
    my ( $self, $t_node ) = @_;

    # some shotcuts (the values are precomputed anyway)
    my $lemma = $t_node->wild->{'deepfix_info'}->{'tlemma'};
    my $lexnode = $t_node->wild->{'deepfix_info'}->{'lexnode'};
    my $parent = $t_node->wild->{'deepfix_info'}->{'parent'};
    if ( !defined $parent ) {
        return;
    }
    my $p_lemma = $t_node->wild->{'deepfix_info'}->{'ptlemma'};
    my $ennode = $t_node->wild->{'deepfix_info'}->{'ennode'};
    my $enlex = defined $ennode ? $ennode->get_lex_anode() : undef;

    # we must have a real node to delete
    return if !defined $lexnode;
    
    # drop only subject pronouns
    return if $t_node->formeme !~ /(:1|^drop)$/;

    # check neighbouring nodes - do not drop if...
    {
        # if the next word is a comma or sám/nic/vše
        my $next_node = $lexnode->get_next_node();
        if ( defined $next_node && $next_node->lemma =~ /^,|nic|vše|sám/) {
            return;
        }
        # if the previous node is nic/vše
        my $prev_node = $lexnode->get_prev_node();
        if ( defined $prev_node && $prev_node->lemma =~ /^nic|vše/) {
            return;
        }
        # if the previous node is a verb (most probably the parent verb)
        if ( defined $prev_node && $prev_node->tag =~ /^V/) {
            return;
        }
    }

    # drop only subjects that are not coordinated ("he or she")
    return if $t_node->is_member;

    return if $parent->is_root();

    # major branching: 'to' or other pronoun?
    if ( $lexnode->form !~ /^to$/i ) {
        
        # some other pronoun than 'to', this is quite easy
        
        # we are interested only in personal pronouns
        if ($lemma ne '#PersPron') {
            return;
        }

        # passed all checks, drop the pronoun!
        # (also ensuring verb-pronoun agreement)
        $self->drop($t_node, 1);
    }
    else {
        
        # the most common and also complicated case is the 'to' (it) pronoun
        
        # this should mean that the 'to' was generated probably thanks to LM;
        # sadly, it is usually only bad alignment,
        # but it still safer to keep such cases as they are
        if ( !defined $enlex ) {
            return;
        }

        # words other than 'it' (this, that...) should usually be kept
        if ( $enlex->form !~ /^it$/i ) {
            return;
        }

        # keep 'To' but shift it
        if ( $lexnode->form ne 'to' ) {
            $self->move($t_node);
            return;
        }

        # set magic=noto to skip dropping 'to'
        if ( $self->magic =~ /noto/ ) {
            return;
        }

        # 'být' and 'znamenat' are often used with 'to'
        if ( $p_lemma =~ /^(být|znamenat)$/ ) {
            return;
        }

        # passed all checks, drop the pronoun!
        $self->drop($t_node);
    }

    return;
}

sub drop {
    my ($self, $t_pronoun, $verb_should_agree ) = @_;

    my $pronoun = $t_pronoun->wild->{'deepfix_info'}->{'lexnode'};
    my $parent_verb = $self->find_verb($t_pronoun);
    
    if ( defined $parent_verb ) {
        if ( $parent_verb->ord > ($pronoun->ord + 1)) {
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

        # enforce agreement before deleting the pronoun
        if ($verb_should_agree) {
            my ($person, $number, $gender) = $self->pronoun2png( $pronoun );
            if ( defined $person ) {
                if ( defined $number ) {
                    $self->change_anode_attribute($parent_verb, 'tag:number',
                        $number, 1);
                }
                if ( defined $gender ) {
                    $self->change_anode_attribute($parent_verb, 'tag:gender',
                        $gender, 1);
                }
                $self->change_anode_attribute($parent_verb, 'tag:person',
                    $person);
            }
        }

        my $result = $self->remove_anode($pronoun);
        if ($result) {
            $self->logfix( "DropSubjPersPron $result" );
        }
        return $result;
    }
    else {
        return;
    }

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
                last;
            }
            else {
                # move up to the parent
                $node = $parent;
            }
        }
    }

    # TODO if not successful, try to find a preceding verb
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

sub move {
    my ($self, $t_pronoun) = @_;

    my $pronoun = $t_pronoun->wild->{'deepfix_info'}->{'lexnode'};
    my $parent_verb = $self->find_verb($t_pronoun);

    if ( defined $parent_verb) {
        # switch the verb and the pronoun
        # (loosely obeying the Wackernagel rule)
        my $msg = 'verb and pronoun swap';
        if ( $parent_verb->ord >= ($pronoun->ord + 2) ) {
            # there is a node between -> swap
            my $parent_verb_orig_preceding = $parent_verb->get_prev_node();
            $parent_verb->shift_before_node(
                $pronoun, { without_children => 1 } );
            $pronoun->shift_after_node(
                $parent_verb_orig_preceding, { without_children => 1 } );
        }
        else {
            # they are next to each other -> 1 shift is enough
            $parent_verb->shift_before_node(
                $pronoun, { without_children => 1 } );
        }
        # fix casing
        $self->change_anode_attribute(
            $pronoun, 'form', lc($pronoun->form), 1 );
        # fix the spaces
        my $swap_temp = $parent_verb->no_space_after;
        $parent_verb->set_no_space_after($pronoun->no_space_after);
        $pronoun->set_no_space_after($swap_temp);
        $self->logfix("DropSubjPersPron $msg");
        return $msg;
    }
    else {
        return;
    }
}

sub pronoun2png {
    my ($self, $pronoun) = @_;

    my $person = $self->get_node_tag_cat($pronoun, 'person');
    $person = undef if $person !~ /^[123]$/;
    
    my $number = $self->get_node_tag_cat($pronoun, 'number');
    $number = undef if $number !~ /^[SPW]$/;
    
    my $gender = $self->get_node_tag_cat($pronoun, 'gender');
    $gender = undef if $gender =~ /^[X-]$/;

    return ($person, $number, $gender);
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::CS::DropSubjPersProns

=head1 DESCRIPTION

Applying pro-drop - deletion of personal pronouns (and "to") in subject positions.

=head1 AUTHOR

Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>
Martin Popel <popel@ufal.mff.cuni.cz>
Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
