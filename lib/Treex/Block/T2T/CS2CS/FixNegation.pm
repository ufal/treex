package Treex::Block::T2T::CS2CS::FixNegation;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::T2T::CS2CS::Deepfix';

has 'magic' => ( is => 'ro', isa => 'Str', default => '' );

sub decide_on_change {
    my ($self, $node_info) = @_;

    if ( $node_info->{formeme} =~ /fin|rc/ ) {

        # double negation
        my @descendants_in_same_clause =
            $node_info->{node}->get_clause_descendants();
        if ( any { $_->t_lemma =~ /^(nikdo|nic|žádný|ničí|nikdy|nikde)$/ }
            @descendants_in_same_clause
        ) {
            $node_info->{change} = 1;
        }

        # until
        if ( $node_info->{enformeme} =~ /(until|unless)/ ) {
            $node_info->{change} = 1;
        }

        # "Ani neprisel, ani nezavolal.", "Nepotkal Pepu ani Frantu."
#        if (
#            grep { $self->_is_ani_neither_nor($_) }
#                $node_info->{node}->get_children()
#            || ( $node_info->{node}->is_member
#                && $self->_is_ani_neither_nor( $node_info->{parent} ) )
#            )
#        {
#            $node_info->{change} = 1;
#        }
    }

    # 'no longer'
    if (
        $node_info->{tlemma} =~ /^(už|již)$/
        && !$node_info->{node}->get_children()
        && !$node_info->{parent}->is_root
        && $node_info->{ptlemma} =~ /^(už|již)$/
    )
    {
        my $grandpa = $node_info->{parent}->get_parent;
        if ( ( $grandpa->gram_sempos || '' ) eq 'v' ) {
            $node_info->{node}->remove; # TODO reflect ina wild attr
            # change the grandpa
            $node_info->{node} = $grandpa;
            $node_info->{change} = 1;
        }
    }

    return;
}


sub _is_ani_neither_nor {
    my ($self, $node) = @_;
    my $result = 0;

    if ($node->t_lemma eq 'ani' ) {
        my ($ennode) = $node->get_aligned_nodes_of_type(
            $self->src_alignment_type
        );
        if (defined $ennode && $ennode->t_lemma =~ /(neither|nor)/) {
            $result = 1;
        }    
    }
    
    return $result; 
}

sub do_the_change {
    my ($self, $node_info) = @_;

    $node_info->{node}->set_gram_negation('neg1');
    $node_info->{'node'}->wild->{'deepfix'}->{'change_node'}->{'tag:neg'}->{'value'} = 1;

    return;
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
