package Treex::Block::T2A::EN::AddInfinitiveParticles;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $t_node ) = @_;
    my ($particles) = ( ( $t_node->formeme || '' ) =~ /^v:([^+]*)\+inf$/ );

    # only for verbal nodes with some particles
    return if ( !$particles );
    my $a_node = $t_node->get_lex_anode() or return;

    foreach my $particle ( split /_/, $particles ) {
        my $particle_node = $a_node->create_child(
            {
                'lemma'        => $particle,
                'form'         => $particle,
                'afun'         => ( $particle eq 'to' ? 'AuxV' : 'AuxC' ),
                'morphcat/pos' => '!',
            }
        );

        # the particle 'to' (default case) goes right before the infinitive
        $particle_node->shift_before_node($a_node);

        # other prepositions than to precede the full subtree (i.e. the 'subject' of the infinitive)
        if ( $particle ne 'to' ) {
            $particle_node->shift_before_subtree($a_node);
        }
        $t_node->add_aux_anodes($particle_node);
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::AddInfinitiveParticles

=head1 DESCRIPTION

The particle 'to' is added to English infinitives. Other prepositions
in constructions such as "It's time for him to go home." are added
as well.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
