package Treex::Block::A2A::NL::EnhanceInterset;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::NL::Pronouns;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $anode ) = @_;
    
    # add gender for 3rd person possessive pronouns; we only know for sure if it's feminine
    # (others default to "zijn" anyway)
    if ( $anode->match_iset( 'prontype' => 'prs', 'poss' => 'poss' ) and $anode->lemma eq 'haar' ) {
        $anode->set_iset( 'possgender' => 'fem' );
    }

    # add politenes to 2nd person possessive pronouns
    if ( $anode->is_pronoun and $anode->lemma eq 'u' ) {
        $anode->set_iset( 'politeness' => 'pol' );
    }

    # check that the subject person agrees with the object person + number, delete reflexivity if it does not
    if ( $anode->match_iset( 'prontype' => 'prs', 'reflex' => 'reflex' ) and $anode->lemma !~ /^zich/ ) {
        my $asubj = $self->_find_subject($anode);
        if ( !$asubj or $asubj->iset->person ne $anode->iset->person or $asubj->iset->politeness ne $anode->iset->politeness ) {
            $anode->set_iset( 'reflex' => '' );
        }
        elsif ( $anode->lemma ne 'je'  and $asubj->iset->number ne $anode->iset->number ){
            if ( $anode->iset->number eq 'sing' or !$asubj->is_member ){
                $anode->set_iset('reflex' => '');
            }           
        }
    }

    # mark relative pronominal adverbs with "waar-" with prontype = 'rel'
    if ( !$anode->iset->prontype and Treex::Tool::Lexicon::NL::Pronouns::is_relative_pronoun( $anode->lemma ) ) {
        $anode->set_iset( 'prontype' => 'rel' );
    }

    return;
}

# Try to find a subject of a clause, given a node in that clause
sub _find_subject {
    my ( $self, $anode ) = @_;

    while ( $anode and not $anode->is_root() and not $anode->get_parent()->is_root ) {

        # go up until you find a verb, then try to find a subject under it
        while ( not $anode->get_parent()->is_root and not $anode->is_verb ) {
            ($anode) = $anode->get_eparents( { or_topological => 1 } );
        }
        my $subj = first { $_->afun eq 'Sb' } $anode->get_echildren( { or_topological => 1 } );
        return $subj if ($subj);

        # try the parent clause (e.g. for infinitive subclauses etc.)
        ($anode) = $anode->get_eparents( { or_topological => 1 } );
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2A::NL::EnhanceInterset

=head1 DESCRIPTION

Enhance Interset values based on current Interset tags, lemmas, and afuns.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
