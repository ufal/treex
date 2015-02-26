package Treex::Block::A2T::ES::SetFormeme;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::SetFormeme';

# semantic adjectives
override 'get_aux_string' => sub {
    my $self = shift;
    my @preps_and_conjs = grep { $self->is_prep_or_conj($_) } @_;
    return join '_', map { lc $_->lemma } @preps_and_conjs;
};


override 'formeme_for_adj' => sub {
    my ( $self, $t_node, $a_node ) = @_;

    my $formeme = super();

    my ($eff_parent) = $t_node->get_eparents() or return $formeme;
    if ($formeme eq "adj:attr" && $t_node->ord() < $eff_parent->ord()) {
	$formeme = "adj:left-attr";
    }

    return $formeme;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::ES::SetFormeme

=head1 DESCRIPTION

The attribute C<formeme> of Spanish t-nodes is filled with
a value which describes the morphosyntactic form of the given
node in the original sentence. Values such as C<v:fin> (finite verb),
C<n:for+X> (prepositional group), or C<n:subj> are used.

=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
