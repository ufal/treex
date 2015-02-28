package Treex::Block::T2A::EN::AddAdjAdvNegation;

use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;

    # select only negated nodes
    return if ( $t_node->gram_negation // '' ) ne 'neg1';

    # verbal negation is handled separately
    return if ( $t_node->formeme =~ /^v/ );

    # avoid cases where the negation is already included in the lemma
    return if ( $t_node->t_lemma =~ /^(un|im|in|irr)/ );

    my $a_node = $t_node->get_lex_anode() or return;

    # try finding a negated lemma to avoid creating the particle
    # TODO make this in a principled way !!!
    if ( my $neg_lemma = $self->get_negated_lemma( $a_node->lemma // '' ) ) {
        return $a_node->set_lemma($neg_lemma);
        return;
    }

    # default to "not"
    # create the particle node, place it before the $node
    my $neg_node = $a_node->create_child(
        {
            'lemma'        => 'not',
            'form'         => 'not',
            'afun'         => 'Neg',
            'morphcat/pos' => '!',
        }
    );
    $neg_node->shift_before_node($a_node);
    $t_node->add_aux_anodes($neg_node);
}

my %NEGATION = (
    'ability'      => 'inability',
    'able'         => 'unable',
    'active'       => 'inactive',
    'configured'   => 'unconfigured',
    'dependent'    => 'independent',
    'dependently'  => 'independently',
    'desirable'    => 'undesirable',
    'desired'      => 'undesired',
    'expected'     => 'unexpected',
    'fair'         => 'unfair',
    'known'        => 'unknown',
    'manageable' => 'unmanageable',
    'patient'      => 'impatient',
    'patiently'    => 'impatiently',
    'possible'     => 'impossible',
    'read'         => 'unread',
    'readable'     => 'unreadable',
    'significant'  => 'insignificant',
    'successful'   => 'unsuccessful',
    'successfully' => 'unsuccessfully',
    'visible'      => 'invisible',
);

sub get_negated_lemma {
    my ( $self, $lemma ) = @_;
    return $NEGATION{$lemma};
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::EN::AddAdjAdvNegation

=head1 DESCRIPTION

Negating adjective and adverb lemmas or adding a negation particle 'not'.

TODO: The lemma negation is now handled by a handwritten list of frequent lemmas. We should
make Morphodita do this for us.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
