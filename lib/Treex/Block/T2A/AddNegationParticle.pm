package Treex::Block::T2A::AddNegationParticle;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode() or return;
    
    # select only negated nodes
    return if ( $t_node->gram_negation || '' ) ne 'neg1';
    
    my $particle = $self->particle_for($t_node);
    return if !defined $particle;

    # create the particle node
    my $neg_node = $a_node->create_child(
        {
            'lemma'        => $particle,
            'form'         => $particle,
            'afun'         => 'Neg',
            'morphcat/pos' => '!',
        }
    );
    $neg_node->shift_before_node($a_node);
    
    $t_node->add_aux_anodes($neg_node);

    return;
}

# to be overriden by language-specific method
sub particle_for {
    my ($self, $t_node) = @_;

    # by default only verbs can take negation
    #return if ( $t_node->gram_sempos || '' ) !~ /^v/;
    
    # "no" is suitable e.g. for Spanish
    return 'no';
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::AddNegationParticle

=head1 DESCRIPTION

Add the particle of negation (e.g. 'not' in English) for nodes with gram/negation=neg1.
Place the particle before the node.

=head1 AUTHORS 

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
