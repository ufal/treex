package Treex::Block::T2A::EN::AddPhrasalVerbParticles;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $t_node ) = @_;
    return if ( ($t_node->formeme // '') !~ /^v/ );
    my ( $verb, $particles ) = ( ( $t_node->t_lemma || '' ) =~ /^([^_]+)_(.*)$/ );

    # only for verbal nodes with some particles
    return if ( !$particles );
    my $a_node = $t_node->get_lex_anode() or return;
    
    # remove particles from the verbal node
    $a_node->set_lemma($verb);

    foreach my $particle ( reverse split /_/, $particles ) {
        my $particle_node = $a_node->create_child(
            {
                'lemma'        => $particle,
                'form'         => $particle,
                'afun'         => 'AuxV',
                'morphcat/pos' => '!',
            }
        );
        $particle_node->shift_after_node($a_node);        
        $t_node->add_aux_anodes($particle_node);
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::AddPhrasalVerbParticles

=head1 DESCRIPTION

Particles belonging to a phrasal verb are added as separate a-nodes.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
