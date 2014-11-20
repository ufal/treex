package Treex::Block::T2A::NL::AddReflexParticles;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

my %refl_forms = (
    '1 sg '       => 'me',
    '2 sg '       => 'je',
    '2 sg basic'  => 'je',
    '2 sg polite' => 'u',
    '3 sg '       => 'zich',
    '1 pl '       => 'ons',
    '2 pl '       => 'je',
    '2 pl basic'  => 'je',
    '2 pl polite' => 'u',
    '3 pl '       => 'zich',
);

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $afun;

    # check if we need to create a reflexive pronoun
    if ( $tnode->t_lemma =~ /^zich_/ ) {
        $afun = 'AuxT';
    }
    elsif ( ( $tnode->voice // $tnode->gram_diathesis // '' ) =~ m/^(reflexive_diathesis|deagent)$/ ) {
        $afun = 'AuxR';
    }
    else {
        return;
    }

    # select the reflexive pronoun form
    my ($anode) = $tnode->get_lex_anode() or return;
    my ( $person, $number, $polite ) = (
        $tnode->gram_person     // '3',
        $tnode->gram_number     // 'sg',
        $tnode->gram_politeness // '',
    );
    my $form = $refl_forms{"$person $number $polite"} or return;

    # create the reflexive pronoun node
    my $ref_node = $anode->create_child(
        {
            'lemma'         => $form,
            'form'          => $form,
            'afun'          => $afun,
            'morphcat/pos'  => '!',
        }
    );
    $ref_node->iset->add('pos' => 'noun', 'prontype' => 'prs', 'reflex' => 'reflex', 'person' => $person);
    $tnode->add_aux_anodes($ref_node);

    # approximate ordering at the 2nd position
    $ref_node->shift_after_node($anode);
    my @constits = $tnode->get_echildren( { ordered => 1, add_self => 1 } );
    if ( not( @constits >= 2 and $tnode == $constits[1] ) ) {
        my $anode_1 = $constits[0]->get_lex_anode() or return;
        $ref_node->shift_after_subtree($anode_1);
    }
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::NL::AddReflexParticles

=head1 DESCRIPTION

Create new a-nodes corresponding to reflexive particles
for reflexive tantum verbs (having 'zich_' in their tlemma) or verbs with 
deagentive (reflexive passive) diathesis.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
