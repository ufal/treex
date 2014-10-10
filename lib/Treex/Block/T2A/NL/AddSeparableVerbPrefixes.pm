package Treex::Block::T2A::NL::AddSeparableVerbPrefixes;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $tnode ) = @_;

    # only for finite verbs in main clause (having no subordinate conjunction and no auxiliaries)
    return if ( ($tnode->formeme // '') ne 'v:fin');
    return if ( ($tnode->gram_deontmod // '') !~ /^(decl|)$/ );
    return if ( ($tnode->gram_tense // '') !~ /^(sim|ant|)$/ );
    return if ( ($tnode->gram_verbmod // '') !~ /^(ind|)$/ );
    return if ( ($tnode->gram_diathesis // '') !~ /^(act|)$/ );
    
    my ( $prefix, $verb ) = ( ( $tnode->t_lemma || '' ) =~ /^([^_]+)_(.*)$/ );

    # only for verbal nodes with some particles
    return if ( !$prefix );
    my $anode = $tnode->get_lex_anode() or return;
        
    # remove prefix from the verbal node
    $anode->set_lemma($verb);

    # create the prefix node
    
    my $prefix_anode = $anode->create_child(
        {
            'lemma'        => $prefix,
            'form'         => $prefix,
            'afun'         => 'AuxV',
            'morphcat/pos' => '!',
        }
    );
    $prefix_anode->iset->add('pos' => 'prep');
    $prefix_anode->shift_after_node($anode);        
    $tnode->add_aux_anodes($prefix_anode);

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
