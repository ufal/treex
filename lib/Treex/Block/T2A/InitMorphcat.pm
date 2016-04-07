package Treex::Block::T2A::InitMorphcat;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %gram2iset = (
    'aspect=proc' => 'aspect=imp',
    'aspect=cpl'  => 'aspect=perf',

    'definiteness=definite'   => 'definiteness=def',
    'definiteness=indefinite' => 'definiteness=ind',
    'definiteness=reduced'    => 'definiteness=red',

    'degcmp=pos'  => 'degree=pos',
    'degcmp=comp' => 'degree=cmp',
    'degcmp=sup'  => 'degree=sup',

    'diathesis=pas' => 'voice=pass',

    'gender=anim' => 'gender=masc',    # Czech-specific relict: grammateme gender mixes animateness and gender
    'gender=inan' => 'gender=masc',
    'gender=fem'  => 'gender=fem',
    'gender=neut' => 'gender=neut',

    'negation=neg1' => 'negativeness=neg',

    'number=sg' => 'number=sing',
    'number=pl' => 'number=plur',
    'number=du' => 'number=dual',

    'numbertype=basic' => 'numtype=card',
    'numbertype=ord'   => 'numtype=ord',
    'numbertype=frac'  => 'numtype=frac',
    'numbertype=kind'  => 'numtype=gen',
    'numbertype=set'   => 'numtype=sets',

    'person=1' => 'person=1',
    'person=2' => 'person=2',
    'person=3' => 'person=3',

    'politeness=basic'  => 'politeness=inf',
    'politeness=polite' => 'politeness=pol',

    'tense=ant'  => 'tense=past',
    'tense=sim'  => 'tense=pres',
    'tense=post' => 'tense=fut',

    'verbmod=ind' => 'mood=ind',
    'verbmod=imp' => 'mood=imp',
    'verbmod=cdn' => 'mood=cnd',
);

my %syntpos2pos = (
    n   => 'noun',
    v   => 'verb',
    adj => 'adj',
    adv => 'adv',
);

sub process_tnode {
    my ( $self, $t_node ) = @_;
    my $a_node = $t_node->get_lex_anode() or return;

    # Skip coordinations, apositions, rhematizers etc.
    return if $t_node->nodetype ne 'complex';

    # Part-of-speech
    # Use mlayer_pos, if available, otherwise try sempos or syntpos from formeme
    my $mlayer_pos = $t_node->get_attr('mlayer_pos');
    if ( defined($mlayer_pos) and $mlayer_pos !~ /^[xX]$/ ) {
        $a_node->iset->set_pos($mlayer_pos);
    }
    else {
        # TODO: this should be probably made with sempos anyway??
        my $syntpos = $t_node->formeme;
        $syntpos =~ s/:.*//;
        my $pos = $syntpos2pos{$syntpos};
        $pos = 'adj' if ( ( $t_node->gram_sempos // '' ) =~ /adj/ );
        $pos = 'num' if ( ( $t_node->gram_sempos // '' ) =~ /quant/ );
        $a_node->iset->set_pos($pos) if $pos;
    }

    # Grammatemes -> Interset features
    my $grammatemes_rf = $t_node->get_attr('gram') or return;
    $self->fill_iset_from_gram( $t_node, $a_node, $grammatemes_rf );

    # Czech-specific relict: grammateme gender contains info about animateness (only for masculine)
    # So far, gram_gender="anim" is used instead of gram_gender="masc", so we cannot induce animateness from this value.
    my $gender = $t_node->gram_gender || '';
    if ( $gender eq 'inan' ) {
        $a_node->iset->set_animateness('inan');
    }

    # The type of pronoun is not preserved on t-layer, but at least we know it is a pronoun
    if ( ( $t_node->gram_sempos // '' ) =~ /pron/ ) {
        $a_node->iset->set_prontype('prn');

        # and we can mark possessive pronouns + move their "gender" and "number" values
        # into possgender and possnumber where they belong
        if ( $t_node->formeme =~ /poss$/ ) {
            $a_node->iset->set_poss('poss');
            $a_node->iset->set_possgender( $a_node->iset->gender );
            $a_node->iset->set_gender('');
            $a_node->iset->set_possnumber( $a_node->iset->number );
            $a_node->iset->set_number('');
            $a_node->iset->set_possperson( $a_node->iset->person );
            $a_node->iset->set_person('');
        }
    }

    # Fill grammatemes through coref_gram.rf for reflexive pronouns
    if ( $t_node->t_lemma eq '#PersPron' and ( my ($t_antec) = $t_node->get_coref_gram_nodes() ) ){
        while ( $t_antec->get_coref_gram_nodes() ){
            ($t_antec) = $t_antec->get_coref_gram_nodes();  # go to the beginng of the coreference chain
        }
        my $antec_gram = $t_antec->get_attr('gram') or return;
        $self->fill_iset_from_gram( $t_node, $a_node, $antec_gram );
        $a_node->iset->set_reflex('reflex');
    }

    return;
}

sub should_fill {
    return 1;
}

sub fill_iset_from_gram {
    my ( $self, $t_node, $a_node, $grammatemes_rf ) = @_;

    while ( my ( $name, $value ) = each %{$grammatemes_rf} ) {
        if ( defined $value && $self->should_fill( $name, $t_node ) && ( my $iset_rule = $gram2iset{"$name=$value"} ) ) {
            my ( $i_name, $i_value ) = split /=/, $iset_rule;
            $a_node->set_iset( $i_name, $i_value );
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2A::InitMorphcat

=head1 DESCRIPTION

Fill Interset morphological categories with values derived from grammatemes and formeme.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
