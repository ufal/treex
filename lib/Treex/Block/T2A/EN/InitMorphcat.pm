package Treex::Block::T2A::EN::InitMorphcat;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %M_GENDER_FOR = (
    masc => 'M',
    fem  => 'F',
    neut => 'N',
);

my %M_DEGREE_FOR = (
    'pos'  => '1',
    'comp' => '2',
    'sup'  => '3',
);

my %CONLL_DEGREE_FOR = (
    'pos'  => '',
    'comp' => 'R',
    'sup'  => 'S',
);

my %M_NUMBER_FOR = (
    pl => 'P',
    sg => 'S',
);

sub process_tnode {

    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode() or return;

    $a_node->reset_morphcat();

    # Skip coordinations, apositions, rhematizers etc.
    # convention: POS="!" means that the word will not be further inflected
    if ( $t_node->nodetype =~ /coap|atom/ ) {
        $a_node->set_morphcat_pos('!');
        return;
    }

    # nouns / pronouns
    my $sempos = $t_node->gram_sempos // '';
    if ( $sempos =~ /^n/ ) {

        $a_node->set_morphcat_pos('N');
        $a_node->set_morphcat_subpos('N');

        my $number = $t_node->gram_number || '';
        $a_node->set_morphcat_number( $M_NUMBER_FOR{$number} // '.' );

        $a_node->set_conll_pos( $number eq 'pl' ? 'NNS' : 'NN' );

        # pronouns
        if ( $t_node->t_lemma eq '#PersPron' ) {
            $a_node->set_morphcat_pos('P');
            $a_node->set_morphcat_subpos('P');

            my $gender = $t_node->gram_gender // '';
            $a_node->set_morphcat_gender( $M_GENDER_FOR{$gender} // '.' );
            $a_node->set_morphcat_person( $t_node->gram_person   // '.' );
            $a_node->set_conll_pos('PRP');
            
            if ($t_node->formeme eq 'n:poss'){ # possessive pronouns
                $a_node->set_morphcat_subpos('S');
                $a_node->set_conll_pos('PRP$');
            }
        }
    }

    # verbs
    elsif ( $sempos =~ /^v/ ) {

        $a_node->set_morphcat_pos('V');
        $a_node->set_conll_pos('VB');

        # voice
        my $voice = $t_node->voice || '';
        if ( $voice eq 'active' ) {
            $a_node->set_morphcat_voice('A');
        }
        elsif ( $voice eq 'passive' ) {
            $a_node->set_morphcat_voice('P');
        }

        # tense
        my $tense = $t_node->gram_tense // '';
        if ( $tense =~ /(sim|post)/ ) {
            $a_node->set_morphcat_tense('P');
        }
        elsif ( $tense eq 'ant' ) {
            $a_node->set_morphcat_tense('R');
            $a_node->set_conll_pos('VBD');
        }

        # infinitives, gerunds
        if ( $t_node->formeme =~ /v.*\+inf/ ) {
            $a_node->set_morphcat_subpos('f');
            $a_node->set_conll_pos('VB');
        }
        elsif ( $t_node->formeme =~ /v.*\+ger/ ) {
            $a_node->set_morphcat_subpos('e');    # let's say it's a "transgressive"
            $a_node->set_conll_pos('VBG');
        }
    }

    # adjectives / adverbs
    elsif ( $sempos =~ /^a/ ) {
        my $pos = ( $sempos =~ /^adj/ ) ? 'A' : 'D';
        my $degree = $t_node->gram_degcmp // '';
        $a_node->set_morphcat_grade( $M_DEGREE_FOR{$degree} // '.' );
        $a_node->set_conll_pos( ( $pos eq 'A' ? 'JJ' : 'RB' ) . ( $CONLL_DEGREE_FOR{$degree} // '' ) );
    }
    else {
        $a_node->set_morphcat_pos('!');
    }

    # negation: all main parts of speech
    if ( $sempos =~ /^[nav]/ and $sempos !~ /pron|quant/ and $t_node->t_lemma ne '#PersPron' ) {
        if ( ( $t_node->gram_negation // '' ) eq 'neg1' ) {
            $a_node->set_morphcat_negation('N');
        }
        else {
            $a_node->set_morphcat_negation('A');
        }
    }

    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::InitMorphcat

=head1 DESCRIPTION

Fill morphological categories with values derived from grammatemes and formeme.

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
