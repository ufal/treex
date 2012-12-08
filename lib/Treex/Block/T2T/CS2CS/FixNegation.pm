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
        my $dofix = 1;

        # bez-, mimo-, proti-, in-...
        if ( $self->cs_lexical_negation($node) ) {
            $dofix = 0;
        }

        # ne, nelze, ne[verb] (nebyl nemá...)
        if ( $self->cs_tree_negation($node) ) {
            $dofix = 0;
        }

        # until
        if ( $self->en_pseudo_negation($ennode) ) {
            $dofix = 0;
        }

        if ($dofix) {
            $self->set_node_neg($node);
        }
    }

    return;
}

# whether the node seems to be negated
# for cs nodes by default,
# for en nodes when $en is set
sub node_is_negated {
    my ($node, $en) = @_;

    if ( !defined $en ) {
        $en = 0;
    }

    my $neg = 0;

    # negation in grammatemes
    if ( defined $node->gram_negation && $node->gram_negation eq 'neg1' ) {
        $neg = 1;
    }

    if (!$en) {
        # negation in Czech formeme
        if ( defined $node->formeme && $node->formeme =~ /[:_]ne/ ) {
            $neg = 1;
        }
    }
    else {
        # negation in English tree
        if ( any { defined $_->t_lemma && $_->t_lemma =~ '^not?$' }
            $node->get_children() )
        {
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

        # && !$node->is_clause_head
      )
    {

        # do not cross clause boundaries;
        # to be sure, do not cross any commas
        my $old_lex = $node->wild->{'deepfix_info'}->{'lexnode'};
        my $new_lex = $node->wild->{'deepfix_info'}->{'parent'}->wild->{'deepfix_info'}->{'lexnode'};
        if ( defined $old_lex && defined $new_lex ) {
            if (
                any {
                    defined $_->form && $_->form =~ /[,;-]/;
                }
                $old_lex->get_nodes_until($new_lex)
              )
            {
                last;
            }
        }

        # if everything OK, move on to the parent
        $node = $node->wild->{'deepfix_info'}->{'parent'};
    }

    if ( node_is_negated($node) ) {

        # node is alreay negate, do not negate it again
        return;
    }

    # negate the first verb anode belonging to this node
    # (except Vc which cannot be negated)
    # or the lex node if there is no such anode
    my $anode =
      ( first { $_->tag =~ /^V[^c]/ } $node->get_anodes( { ordered => 1 } ) )
      // $node->wild->{'deepfix_info'}->{'lexnode'};

    if ( defined $anode ) {
        $node->set_gram_negation('neg1');
        my $msg = $self->change_anode_attribute( 'tag:neg', 'N', $anode );
        if ( $anode->lemma =~ /^muset/ ) {
            $msg .= $self->change_anode_attribute( 'lemma', 'smět', $anode );
        }
        $self->logfix($msg);
    }
    else {
        log_warn( "No lex node for "
              . $self->tnode_sgn($node)
              . ", cannot perform the fix!" );
    }

    return;
}

sub cs_lexical_negation {
    my ( $self, $node ) = @_;

    my $result = 0;

    if ( $node->t_lemma =~ /^(ne|bez|mimo|proti|in|dis|dys|zbyt)/ ) {
        $result = 1;
    }

    # TODO: use the parsed formeme structure?
    if ( $node->formeme =~ /[:_](ne|bez|mimo|proti)/ ) {
        $result = 1;
    }

    return $result;
}

sub cs_tree_negation {
    my ( $self, $node ) = @_;

    my $result = 0;

    my $has_negated_child = any { node_is_negated($_) } $node->get_children();
    if ($has_negated_child) {
        $result = 1;
    }

    return $result;
}

sub en_pseudo_negation {
    my ( $self, $ennode ) = @_;

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
