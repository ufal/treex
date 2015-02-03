package Treex::Block::T2A::NL::Alpino::FixInfinitiveParticles;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    # return if we don't have any infinitive particles
    return if ( $tnode->formeme !~ /^v:.*te\+inf$/ );

    my $aaux_te = first { $_->lemma eq 'te' } $tnode->get_aux_anodes();
    return if !$aaux_te;
    my $amain_verb = $tnode->get_lex_anode();
    return if !$amain_verb;

    # swap the verb and the particle "te"
    $aaux_te->set_parent( $amain_verb->get_parent() );
    $amain_verb->set_parent($aaux_te);
    $aaux_te->set_is_member( $amain_verb->is_member );
    $amain_verb->set_is_member();

}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::Alpino::FixInfinitiveParticles

=head1 DESCRIPTION

Making the te particle to be the head of the infinitive phrase, making all other infinitive
particles depend on "te" instead of the verb.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

    
