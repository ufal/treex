package Treex::Block::T2T::CS2CS::FixNegation;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::T2T::CS2CS::Deepfix';

sub fill_node_info {
    my ( $self, $node ) = @_;

    $self->fill_info_basic($node);
    $self->fill_info_lexnode($node);
    $self->fill_info_aligned($node);

    return;
}

sub fix {
    my ( $self, $node ) = @_;

    my $ennode = $node->wild->{'deepfix_info'}->{'ennode'}; 
    if (defined $ennode
        && defined $ennode->gram_negation
        && $ennode->gram_negation eq 'neg1'
        && defined $node->gram_negation
        && $node->gram_negation eq 'neg0'
    ) {
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

sub set_node_neg {
    my ( $self, $node ) = @_;

    my $lexnode = $node->wild->{'deepfix_info'}->{'lexnode'};
    if ( defined $lexnode ) {
        $node->set_gram_negation('neg1');

        # TODO sometimes do not set the neg on the lex node but on its active verb
        my $msg = $self->change_anode_attribute( 'tag:neg', 'N', $lexnode );
        $self->logfix($msg);
    }
    else {
        log_warn(
            "No lex node for "
                . $self->tnode_sgn($node)
                .
                ", cannot perform the fix!"
        );
    }

    return;
}

sub cs_lexical_negation {
    my ($self, $node) = @_;

    my $result = 0;

    if ( $node->wild->{'deepfix_info'}->{'tlemma'} =~ /^(ne|bez|mimo|proti|in|dis|dys)/ ) {
        $result = 1;
    }

    return $result;
}

sub cs_tree_negation {
    my ($self, $node) = @_;

    my $result = 0;

    my $has_negated_child = any { $_->gram_negation eq 'neg1' } $node->get_children();
    if ( $has_negated_child ) {
        $result = 1;
    }

    return $result;
}

sub en_pseudo_negation {
    my ($self, $ennode) = @_;

    my $result = 0;

    my $has_until_child = any { $_->t_lemma eq 'until' } $ennode->get_children();
    if ( $has_until_child ) {
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

=head1 PARAMETERS

=over

=back

=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
