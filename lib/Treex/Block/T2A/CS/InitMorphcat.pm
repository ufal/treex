package Treex::Block::T2A::CS::InitMorphcat;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %M_GENDER_FOR = (
    anim => 'M',
    inan => 'I',
    fem  => 'F',
    neut => 'N',
);

my %M_NUMBER_FOR = (
    pl => 'P',
    sg => 'S',
);

my %M_DEGREE_FOR = (
    'pos'  => '1',
    'comp' => '2',
    'sup'  => '3',
);

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode() or return;

    # Initialize all categories to '.' so it can be used in regexes
    $a_node->reset_morphcat();

    # Skip coordinations, apositions, rhematizers etc.
    # convention: POS="!" means that the word will not be further inflected
    if ( $t_node->nodetype =~ /coap|atom/ ) {
        $a_node->set_attr( 'morphcat/pos', '!' );
        return;
    }

    # == POS ==
    # M-layer part of speech should be already known since it is saved in the dictionary
    $a_node->set_attr( 'morphcat/pos', $t_node->get_attr('mlayer_pos') || '.' );

    if ( ( $t_node->formeme || '' ) =~ /^v/ ) {
        $a_node->set_attr( 'morphcat/pos', 'V' );    # !!! hack to surpress some inconsistencies during transfer
    }
    
    if ($t_node->t_lemma eq ':'){
        $a_node->set_attr( 'morphcat/pos', 'Z' );
    }

    # == Person ==
    my $person = $t_node->gram_person || '.';
    ##if ( $person eq 'inher' ) { $person = '.'; }   # not needed yet
    $a_node->set_attr( 'morphcat/person', $person );

    # == Number, Gender ==
    # Generally, number and gender is copied from respective grammatemes
    # M-layer number and gender of possessive pronouns (moje,moji,můj,...)
    # is determined by agreement with governing noun,
    # but this is handled in another block (Impose_rel_pron_agr).
    my $number = $t_node->gram_number || '';
    my $gender = $t_node->gram_gender || '';
    $a_node->set_attr( 'morphcat/number', $M_NUMBER_FOR{$number} || '.' );
    $a_node->set_attr( 'morphcat/gender', $M_GENDER_FOR{$gender} || '.' );

    # Personal pronouns must be handled specially:
    # There is a complex subpos system for pronouns,
    # also possnumber and possender should be handled.
    if ( $t_node->t_lemma eq '#PersPron' ) {
        $a_node->set_attr( 'morphcat/pos', 'P' );
        my $subpos = get_subpos_of_perspron( $a_node, $t_node, $person );
        $a_node->set_attr( 'morphcat/subpos', $subpos );
    }

    my $sempos = $t_node->gram_sempos || '';
    my $formeme = $t_node->formeme;

    # Subpos of possessive nouns/adjectives  # moved to a dedicated block
    #    if ( $sempos =~ /^n.denot/ && $formeme =~ /poss/ ) {
    #        $a_node->set_attr( 'morphcat/subpos', 'U' );
    #    }

    # == Case ==
    if ( $a_node->get_attr('morphcat/case') eq '.' ){
        if ( $formeme =~ /(\d)/ ) {
            $a_node->set_attr( 'morphcat/case', $1 );
        }
        elsif ( $formeme eq 'drop' ){
            $a_node->set_attr( 'morphcat/case', '1' );
        }
        elsif ( $formeme =~ /adj:za\+X/ ) {
            $a_node->set_attr( 'morphcat/case', '4' );
        }
    }

    # == Degree of comparison ==
    my $degree = $t_node->gram_degcmp || '';
    if ( $degree eq 'pos' && $sempos =~ /pron|quant/ ) { $degree = ''; }
    $a_node->set_attr( 'morphcat/grade', $M_DEGREE_FOR{$degree} || '.' );

    # == Negation ==
    # urcovani negace (jen u subst,adj. a adv.) z gramatemu  (u sloves se resi zvlast)
    # TODO pozor na nenegovatelna prislovce, asi spojit s degcmp!!!
    if ( $sempos =~ /^[nav]/ and $t_node->t_lemma ne '#PersPron' and $sempos !~ /pron|quant/ ) {
        if ( ( $t_node->gram_negation || '' ) eq 'neg1' ) {
            $a_node->set_attr( 'morphcat/negation', 'N' );
        }
        else {
            $a_node->set_attr( 'morphcat/negation', 'A' );
        }
    }

    # == Verbal voice ==
    if ( $sempos =~ /^v/ ) {
        my $voice = $t_node->voice || '';
        if ( $voice eq 'active' ) {
            $a_node->set_attr( 'morphcat/voice', 'A' );
        }
        elsif ( $voice eq 'passive' ) {
            $a_node->set_attr( 'morphcat/voice', 'P' );
        }
    }
    return;
}

# Returns second position of tag for personal pronouns.
# Also possnumber and possgender is filled if needed.
sub get_subpos_of_perspron {
    my ( $a_node, $t_node, $person ) = @_;
    my $formeme = $t_node->formeme;

    if ( $formeme =~ /(poss|attr)/ ) {

        # Subpos=8 implies m-lemma "svůj"
        # If perspron corefers to the subject of a clause, m-lemma "svůj", should be used
        # execept for nominative ("Mají štěstí jako *sví rodiče." hidden clause?).
        # TODO: check whether it is really a coreference from possesive to the subject
        #       (we don't mark any other type yet, so it is ok).
        my ($noun) = $t_node->get_eparents();
        if ( $t_node->get_attr('coref_gram.rf') && $noun && $noun->formeme !~ /1/ ) {
            ## reflexive lemma "svůj" doesn't have person in the tag
            $a_node->set_attr( 'morphcat/person', '.' );
            return '8';
        }

        # Possesive pronouns (except svůj) should have filled possnumber and possgender
        my $possnumber = $t_node->gram_number || '';
        $a_node->set_attr( 'morphcat/possnumber', $M_NUMBER_FOR{$possnumber} || '.' );
        if ( $person eq '3' ) {
            my $possgender = $t_node->gram_gender || '';
            $a_node->set_attr( 'morphcat/possgender', $M_GENDER_FOR{$possgender} || '.' );
        }
        return 'S';
    }

    # Reflexive pronouns can have long ("sebe") or short ("se","si") forms
    if ( $t_node->get_attr('is_reflexive') ) {
        ## reflexive lemmas don't have person in the tag
        $a_node->set_attr( 'morphcat/person', '.' );
        return '7' if $formeme =~ /[^+][34]/;    # no preposition -> short form
        return '6';                              # with preposition -> long form (pro sebe, za sebou)
    }

    # persprons after preposition
    if ( $formeme =~ /^n.*\+/ ) {
        return '5' if $person eq '3';            # "pro něj"
        return 'P';                              # "pro tebe"
    }

    # short pronoun forms ("ho")
    return 'H' if $formeme =~ /[34]/ && ($t_node->gram_number || '') eq 'sg' && ($t_node->gram_gender || '') ne 'fem';

    # other personal pronouns (on, jich, ...)
    return 'P';
}

1;

__END__

=over

=item Treex::Block::T2A::CS::InitMorphcat

Fill TCzechA morphological categories (members of structure morphcat) with
values simply derived from values of grammatemes, formeme, sempos etc.

=back

=cut

# Copyright 2008-2009 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
