package Treex::Block::T2A::AddInfinitiveParticles;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $t_node ) = @_;
    my ($particles) = $self->get_particle_forms( $t_node->formeme // '' );

    # only for verbal nodes with some particles
    return if ( !$particles );
    my $a_node = $t_node->get_lex_anode() or return;

    # remember this in case there are more `conjunctions' so as not to reverse order
    my $last_conj = undef;

    foreach my $particle ( split /_/, $particles ) {

        my $works_as_conj = $self->works_as_conj($particle);

        my $particle_node = $a_node->create_child(
            {
                'lemma'        => $particle,
                'form'         => $particle,
                'afun'         => ( $works_as_conj ? 'AuxC' : 'AuxV' ),
                'morphcat/pos' => '!',
            }
        );

        if ( not $works_as_conj ) {
            $particle_node->shift_before_node($a_node);
            $particle_node->iset->add( pos => 'part', parttype => 'inf' );
        }
        else {
            if ($last_conj) {
                $particle_node->shift_after_node($last_conj);
            }
            else {
                $particle_node->shift_before_subtree($a_node);
            }
            $last_conj = $particle_node;
            $particle_node->iset->add( pos => 'conj', conjtype => 'sub' );
            $particle_node->set_parent( $a_node->get_parent );
            $particle_node->set_is_member( $a_node->is_member );
            $a_node->set_is_member();
            $a_node->set_parent($particle_node);
        }
        $t_node->add_aux_anodes($particle_node);
    }

    return;
}

# This should be overridden for different languages (for particles that don't go straight
# before the infinitive, but rather before the whole clause)
sub works_as_conj {
    return 0;
}

# Extract all particles from the formeme
sub get_particle_forms {
    my ( $self, $formeme ) = @_;
    my ($particles) = ( $formeme =~ /^v:([^+]*)\+inf$/ );
    return $particles;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::AddInfinitiveParticles

=head1 DESCRIPTION

Adding infinitive particles. By default all of them get 'AuxV' and are placed straight
before the infinitive.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
