package Treex::Block::T2T::CS2CS::FixNegation;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::T2T::CS2CS::Deepfix';

has 'magic'              => ( is => 'ro', isa => 'Str', default => '' );

sub fill_node_info {
    my ( $self, $node ) = @_;

    $self->fill_info_basic($node);
    $self->fill_info_lexnode($node);
    $self->fill_info_aligned($node);

    return;
}

sub fix {
    my ( $self, $node ) = @_;

    if ( $node->formeme =~ /fin|rc/ ) {

        # double negation
        my @descendants_in_same_clause = $node->get_clause_descendants();
        if (any { $_->t_lemma =~ /^(nikdo|nic|žádný|ničí|nikdy|nikde)$/ }
            @descendants_in_same_clause
            )
        {
            $self->set_node_neg($node);
        }

        # until
        if ( $node->wild->{'deepfix_info'}->{enformeme} =~ /(until|unless)/ ) {
            $self->set_node_neg($node);
        }

        # "Ani neprisel, ani nezavolal.", "Nepotkal Pepu ani Frantu."
        if (grep { $self->_is_ani_neither_nor($_) }
            $node->get_children
            or ($node->is_member
                and $self->_is_ani_neither_nor( $node->get_parent )
            )
            )
        {
            $self->set_node_neg($node);
        }
    }

    # 'no longer'
    if (
        $node->wild->{'deepfix_info'}->{tlemma} =~ /^(už|již)$/
        && !$node->get_children()
        && !$node->wild->{'deepfix_info'}->{parent}->is_root
        && $node->wild->{'deepfix_info'}->{ptlemma} =~ /^(už|již)$/
        )
    {
        my $grandpa = $node->wild->{'deepfix_info'}->{parent}->get_parent;
        if ( ( $grandpa->gram_sempos || '' ) eq 'v' ) {

            # remove the node
            my $msg = $self->remove_anode(
                $node->wild->{'deepfix_info'}->{'lexnode'}
            );
            $self->logfix( $msg, 1 );

            # change the grandpa
            $self->set_node_neg($grandpa);
        }
    }

    return;
}

sub set_node_neg {
    my ( $self, $node ) = @_;

    my $lexnode = $node->wild->{'deepfix_info'}->{'lexnode'};
    if ( defined $lexnode ) {
        $node->set_gram_negation('neg1');
        my $msg = $self->change_anode_attribute( 'tag:neg', 1, $lexnode );
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

sub _is_ani_neither_nor {
    my ( $self, $node ) = @_;
    my $result = 0;

    if ( $node->t_lemma eq 'ani' ) {
        my ($ennode) = $node->get_aligned_nodes_of_type(
            $self->src_alignment_type
        );
        if ( defined $ennode && $ennode->t_lemma =~ /(neither|nor)/ ) {
            $result = 1;
        }
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
