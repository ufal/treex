package Treex::Block::T2T::CS2CS::FixNegation;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::T2T::CS2CS::Deepfix';

sub fix {
    my ( $self, $node ) = @_;

    my $ennode = $node->wild->{'deepfix_info'}->{'ennode'};
    if (   defined $ennode
        && node_is_negated($ennode, 1)
        && !node_is_negated($node) )
    {
        $self->set_node_neg($node);
    }

    return;
}

# whether the node seems to be negated
# for cs nodes by default,
# for en nodes when $is_en is set
# TODO probably inline all
sub node_is_negated {
    my ($node, $is_en, $no_tree_neg) = @_;

    if ( !defined $is_en ) {
        $is_en = 0;
    }
    if ( !defined $no_tree_neg ) {
        $no_tree_neg = 0;
    }

    my $neg = 0;

    # negation in grammatemes
    if ( defined $node->gram_negation && $node->gram_negation eq 'neg1' ) {
        $neg = 1;
    }

    if ($is_en) {
        # negation in English tree (no, not)
        if ( any { defined $_->t_lemma && $_->t_lemma =~ '^not?$' }
            $node->get_children() )
        {
            $neg = 1;
        }
        # until
        if ( en_pseudo_negation($node) ) {
            $neg = 0;
        }
    }
    else {
        # bez-, mimo-, proti-, in-...
        if ( cs_lexical_negation($node) ) {
            $neg = 1;
        }
        # ne, nelze, ne[verb] (nebyl nemá...)
        if ( !$no_tree_neg && cs_tree_negation($node) ) {
            $neg = 1;
        }
    }

    return $neg;
}

sub set_node_neg {
    my ( $self, $node ) = @_;

    # do not negate the infinitive but its finite parent
    while (
           $node->formeme !~ /v:.*fin/
        && defined $node->wild->{'deepfix_info'}->{'parent'}
        && $node->wild->{'deepfix_info'}->{'parent'}->formeme =~ /v:.*fin/
      )
    {

        my $parent = $node->wild->{'deepfix_info'}->{'parent'};
        
        if ( $self->nodes_in_different_clauses($node, $parent) == 1 ) {
            # do not cross clause boundaries
            last;
        }
        else {
            # move up to the parent
            $node = $parent;
        }
    }

    if ( node_is_negated($node) ) {

        # node is already negated, do not negate it again
        return;
    }

    # do not negate if the node has a negated parent or grandparent
    # in the same clause
    # (leads to lower recall but higher prescision)
    {
        # check parent
        my $parent = $node->wild->{'deepfix_info'}->{'parent'};
        if ( defined $parent
            && $self->nodes_in_different_clauses($node, $parent) != 1
        ) {
            if ( node_is_negated($parent) ) {
                return;
            }
            
            # check grandparent
            my $grandparent = $parent->wild->{'deepfix_info'}->{'parent'};
            if ( defined $grandparent
                && $self->nodes_in_different_clauses($node, $grandparent) != 1
            ) {
                if ( node_is_negated($grandparent) ) {
                    return;
                }
            }
        }
    }

    # negate the first verb anode belonging to this node
    # (except Vc which cannot be negated)
    # or the lex node if there is no such anode
    my $anode =
      ( first { $_->tag =~ /^V[^c]/ } $node->get_anodes( { ordered => 1 } ) )
      // $node->wild->{'deepfix_info'}->{'lexnode'};

    if ( defined $anode ) {
        $node->set_gram_negation('neg1');
        my $msg = $self->change_anode_attribute( $anode, 'tag:neg', 'N' );
        if ( !$msg
            && $node->wild->{'deepfix_info'}->{'formeme'}->{'syntpos'} eq 'v'
        ) {
            $msg = $self->change_anode_attributes( $anode, {
                    form  => ('ne' . $anode->form),
                    lemma => ('ne' . $anode->lemma),
                }, 1);
        }
        if ( $anode->lemma =~ /^muset/ ) {
            $msg .= $self->change_anode_attribute( $anode, 'lemma', 'smět' );
        }
        $self->logfix("Negation $msg");
    }
    else {
        log_warn( "No lex node for "
              . $self->tnode_sgn($node)
              . ", cannot perform the fix!" );
    }

    return;
}

sub cs_lexical_negation {
    my ( $node ) = @_;

    my $result = 0;

    if ( $node->wild->{'deepfix_info'}->{'tlemma'}
        =~ /^(ne|bez|mimo|proti|il|mis|anti|dis|dys|zbyt)/
        # =~ /^(ne|bez|mimo|proti|in|il|ir|im|mis|anti|dis|dys|zbyt)/
    ) {
        $result = 1;
        # there are exceptions (quickly manually devised list based on PCEDT
        # train data)
        if ( $node->wild->{'deepfix_info'}->{'tlemma'} =~ /^nechť|nebo|neboli|neboť|nechat|nechávat|nemovitost|nemoc.*|nerv.*|neur.*|neděle|než|new.*|neutr.*|nerost|neustál.*|nebe|nebes.*|nedávno|nedaleko|nerez.*|nemálo|nevěsta|netopýr$/
        ) {
            $result = 0;
        }
    }

    if ( $node->wild->{'deepfix_info'}->{'formeme'}->{'prep'}
        =~ /bez|mimo|proti/
    ) {
        $result = 1;
    }

    return $result;
}

sub cs_tree_negation {
    my ( $node ) = @_;

    my $result = 0;

    my $has_negated_child = any { node_is_negated($_, 0, 1) } $node->get_children();
    if ($has_negated_child) {
        $result = 1;
    }

    return $result;
}

sub en_pseudo_negation {
    my ( $ennode ) = @_;

    my $result = 0;

    my $has_until_child =
      any { $_->formeme =~ 'until' } $ennode->get_children();
    if ($has_until_child) {
        $result = 1;
    }

    return $result;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CS2CS::FixNegation -
An attempt to fix missing negation. 
(A Deepfix block.)

=head1 DESCRIPTION

Partly based on Treex::Block::T2T::EN2CS::FixNegation.

If the English t-node is negated but the Czech one is not,
it negates it (changing the corresponding a-node as well).
It does not perform the fix if the node seems to be negated indirectly.
It tries to find the best node to negate,
which is typically the closest finite verb parent.

Known issues:

=over

=item does not handle double negation in English

=item cannot handle 'until' correctly (thus does not try to fix such cases)

=item only adds negation, does not remove it

=item if the negation marker is misplaced in English, it has a false positive...

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
