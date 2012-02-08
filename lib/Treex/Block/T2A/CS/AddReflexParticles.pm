package Treex::Block::T2A::CS::AddReflexParticles;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $reflexive;
    my $afun;

    if ( $t_node->t_lemma =~ /_(s[ie])$/ ) {
        $reflexive = $1;
        $afun      = 'AuxT';
    }
    elsif ( ( $t_node->voice || $t_node->gram_diathesis || '' ) =~ m/^(reflexive_diathesis|deagent)$/ ) {
        $reflexive = 'se';
        $afun      = 'AuxR';
    }
    else {
        return;
    }

    my $a_node    = $t_node->get_lex_anode();
    my $refl_node = $a_node->create_child();
    $refl_node->reset_morphcat();
    $refl_node->set_form($reflexive);
    $refl_node->set_lemma($reflexive);
    $refl_node->set_afun($afun);
    $refl_node->set_attr( 'morphcat/pos',    'P' );
    $refl_node->set_attr( 'morphcat/subpos', '7' );
    $refl_node->set_attr( 'morphcat/number', 'X' );
    $refl_node->set_attr( 'morphcat/case',   $reflexive eq 'si' ? 3 : 4 );
    $refl_node->wild->{lex_verb_child} = ( $afun eq 'AuxT' ? 1 : 0 );

    $t_node->add_aux_anodes($refl_node);

    # Correct position will be found later (Move_clitics_to_wackernagel),
    # but some ord must be filled now (place it just after the verb).
    $refl_node->shift_after_node($a_node);
    return;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::CS::AddReflexParticles

=head1 DESCRIPTION

Create new a-nodes corresponding to reflexive particles
for reflexive tantum verbs (having '_si' or '_se' in their tlemma) or verbs with 
deagentive (reflexive passive) diathesis.

=head1 AUTHORS

Zdeněk Žabokrtský <zaborktsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
