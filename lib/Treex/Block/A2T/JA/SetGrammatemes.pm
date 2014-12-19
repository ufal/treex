package Treex::Block::A2T::JA::SetGrammatemes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::JA;

Readonly my $DEBUG => 0;

#------ Constants --------
# Some tags should not appear on the t-layer:
# Particles, symbols, etc.
# We take first two tag levels so we can distinguish between nouns, numerals and pronouns
Readonly my %SUB_FOR_TAG => (
  'Keiyōshi-Jiritsu'          => \&_adj,
  'Keiyōshi-HiJiritsu'        => \&_adj,
  'Dōshi-Jiritsu'             => \&_verb,
  'Dōshi-HiJiritsu'           => \&_verb,
  'Fukushi-Ippan'             => \&_adv,
  'Fukushi-JoshiRuiSetsuzoku' => \&_adv,
  'Meishi-SahenSetsuzoku'     => \&_noun,
  'Meishi-NaiKeiyōshiGokan'   => \&_noun,
  'Meishi-Ippan'              => \&_noun,
  'Meishi-InYōmojiretsu'      => \&_noun,
  'Meishi-KeiyōdōshiGokan'    => \&_noun,
  'Meishi-Koyūmeishi'         => \&_noun,
  'Meishi-SetsuzokushiTeki'       => \&_noun,
  'Meishi-Setsubi'            => \&_noun,
  'Meishi-DōshiHiJiritsuTeki' => \&_noun, # or should it be _verb?
  'Meishi-Tokushu'            => \&_noun,
  'Meishi-HiJiritsu'          => \&_noun,
  'Meishi-FukushiKanō'        => \&_noun,
  'Meishi-Daimeishi'          => \&_pron,
  'Meishi-Kazu'               => \&_number,
  'Rentaishi-*'               => \&_adj,  # or maybe a class of its own
);

# modal verb -> gramm/deontmod mapping
# TODO: fill this
Readonly my %DEONTMOD_FOR_LEMMA => (

);

# $form => $gender . $number . $person . $politeness
# we only distinguish polite form vs basic form (PDT style)
# archaic personal pronouns are not included

Readonly my %PERSPRON_INFO => (
  # kanji representation
  '私'      => '-S1X',
  '我'      => '-S1Y',
  '吾'      => '-S1Y',
  '我が'    => '-S1Y',
  '俺'      => 'MS1X',
  '僕'      => 'MS1X',
  '儂'      => 'MS1X',
  '自分'    => 'MS1X', # "oneself", so maybe undetermined gender
  '家'      => 'FS1X',
  '内'      => 'FS1X', 
  '貴方'    => '-S2X',
  '貴男'    => 'MS2X', # gender based on the second kanji (male)
  '貴女'    => 'FS2X', # gender based on the second kanji (female)
  'お宅'    => '-S2Y',
  '御宅'    => '-S2Y',
  'お前'    => '-S2X',
  '手前'    => '-S2X',
  '貴様'    => '-S2X',
  '君'      => '-S2X',
  '貴下'    => '-S2X',
  '貴官'    => '-S2Y',
  '御社'    => '-S2Y',
  '貴社'    => '-S2Y',
  'あの方'  => '-S3Y',
  'あの人'  => '-S3X',
  '奴'      => 'MS3X',
  '此奴'    => '-S3X', 
  '其奴'    => '-S3X', 
  '彼奴'    => '-S3X',
  '彼'      => 'MS3Y',
  '彼女'    => 'FS3Y', 
  '我々'    => '-P1Y',
  '我等'    => '-P1X',
  '弊社'    => '-P1Y',
  '我が社'  => '-P1Y',
  '彼等'    => '-P3X',

  # hiragana transcriptions & pronouns without kanji form
  'わたし'    => '-S1X',
  'わたくし'  => '-S1Y',
  'われ'      => '-S1Y',
  'わが'      => '-S1Y', 
  'おれ'      => 'MS1X',
  'ぼく'      => 'MS1X',
  'わし'      => 'MS1X',
  'じぶん'    => 'MS1X',
  'あたい'    => 'FS1X',
  'あたし'    => 'FS1X',
  'あたくし'  => 'FS1X',
  'うち'      => 'FS1X',
  'おいら'    => '-S1X',
  'おら'      => '-S1X',
  'わて'      => '-S1X',
  'あなた'    => '-S2X',
  'あんた'    => '-S2X',
  'おたく'    => '-S2Y',
  'おまえ'    => '-S2X',
  'てめえ'    => '-S2X',
  'てまえ'    => '-S2X',
  'きさま'    => '-S2X',
  'きみ'      => '-S2X',
  'きか'      => '-S2X',
  'きかん'    => '-S2Y',
  'おんしゃ'  => '-S2Y',
  'きしゃ'    => '-S2Y',
  'あのかた'  => '-S3Y',
  'あのひと'  => '-S3X',
  'やつ'      => 'MS3X',
  'こいつ'    => '-S3X',
  'こやつ'    => '-S3X',
  'そいつ'    => '-S3X',
  'そやつ'    => '-S3X',
  'あいつ'    => '-S3X',
  'あやつ'    => '-S3X',
  'かれ'      => 'MS3Y',
  'かのじょ'  => 'FS3Y',
  'われわれ'  => '-P1Y',
  'われら'    => '-P1X',
  'へいしゃ'  => '-P1Y',
  'わがしゃ'  => '-P1Y',
  'かれら'    => '-P3X',
);

Readonly my %TECTO_NAME_FOR => (
    'F' => 'fem', 'M' => 'anim', 'N' => 'neut',
    'S' => 'sg',  'P' => 'pl',
    '1' => '1',   '2' => '2',    '3' => '3',
    'X' => 'basic', 'Y' => 'polite',
    '-' => 'nr',
);

Readonly my %TECTO_PERSON_INFO =>
    map { ( $_ => _get_tecto_info( $PERSPRON_INFO{$_} ) ) } keys %PERSPRON_INFO;

sub _get_tecto_info {
    my ($gender_number_person) = @_;
    my ( $gender, $number, $person, $politeness ) = split( //, $gender_number_person );
    my @tecto_info = @TECTO_NAME_FOR{ ( $gender, $number, $person , $politeness) };
    return \@tecto_info;
}



#------ Main loop --------
sub process_tnode {
    my ( $self, $t_node ) = @_;
#    return if $t_node->nodetype ne 'complex';

    # Sempos of all complex nodes should be defined,
    # so initialize it with a default value.
    $t_node->set_gram_sempos('???');

    assign_grammatemes_to_tnode($t_node);
    return;
}

sub assign_grammatemes_to_tnode {
    my ($tnode) = @_;
    my $lex_anode = $tnode->get_lex_anode() or return;
    my $tag = $lex_anode->tag;
    my $form = $lex_anode->form;
    my $lemma = $lex_anode->lemma;

    $tag =~ s{^([^\-]+)\-([^\-]+)\-[^\-]+\-[^\-]+}{$1\-$2}g;

    my $sub_ref = $SUB_FOR_TAG{$tag};
    if ( defined $sub_ref ) {
      $sub_ref->( $tnode, $tag, $form, $lemma );
    }
    elsif ( $DEBUG and all { $_ ne $tag } qw(: '' ``) ) {
        warn "Grammatems not assigned to: $form\t$tag\n";
    }
    
    # TODO: do it better and for all types of nodes

    return;

}

#------ Subs for each POS --------
# Nouns
sub _noun {
  my ( $tnode, $tag, $form, $lemma ) = @_;
  $tnode->set_gram_sempos('n.denot');
  
  # Japanese nouns do not explicitly express gramatical number (this knowledge is usually extracted from the context), but we would like to set it anyway
  # as a default, we set number to 'sg'
  my $number = 'sg';
  # TODO: depending on the context, set the number correctly

  # Japanese nouns do not express gramatical gender
  # TODO: figure out how to get this information anyway?

  # we use only simple heuristic now
  $number = 'pl' if (_has_numeral_child($tnode));

  # plural by duplication (not exactly pure plural, e.g. 人(hito = person) => 人々(hitobito = people)
  # this should be also fine thanks to POS: 色(iro = color) - noun => 色々(iroiro = various) - adverb 
  $number = 'pl' if ( $lemma =~ /々/ );

  $tnode->set_gram_number($number);

  return;  
}

sub _has_numeral_child {
  my ($tnode) = @_;

  return if ( grep { $_->get_lex_anode->tag =~ /Kazu/ } $tnode->get_children() );

  return any {
      ( Treex::Tool::Lexicon::JA::number_for( $_->t_lemma ) || 0 ) > 1;
  }
  $tnode->get_children();
}

# Adjectives
sub _adj {
  my ( $tnode, $tag, $form, $lemma ) = @_;

  $tnode->set_gram_sempos('adj.denot');
  $tnode->set_gram_negation('neg0');

  # Japanese adjectives are non-gradable
  $tnode->set_gram_degcmp('pos');

  return;
}

# Adverbs
sub _adv {
  my ( $tnode, $tag, $form, $lemma ) = @_;
  
  # All Japanese adverbs cannot be negated
  # Japanese adverbs are non-gradable
  # TODO: Is that really correct?
  $tnode->set_gram_sempos('adv.denot.ngrad.nneg'); 
  $tnode->set_gram_negation('neg0');

  # Japanese adverbs are non-gradable
  # $tnode->set_gram_degcmp('pos');

  return;
}

# Pronouns
sub _pron {
  my ( $tnode, $tag, $form, $lemma ) = @_;

  # Personal pronouns
  if ( Treex::Tool::Lexicon::JA::is_pers_pron($lemma) ) {
    $tnode->set_gram_sempos('n.pron.def.pers');
    if ( $form =~ /^(自分|じぶん)$/ ) {
      $tnode->set_attr('is_reflexive', 1);
    }
  
    my $info_ref = $TECTO_PERSON_INFO{$form};

    if ( !defined $info_ref ) {
      warn "No morpho info for: $form\t$tag\n" if $DEBUG;
      $info_ref = [ 'nr', 'nr', 'nr', 'nr' ];
    }

    # TODO: pronouns with plural suffix 達(tachi) are tokenized separately

    # fix number of some pronouns
    $info_ref->[1] = 'pl' if ( $lemma =~ /々/ );

    $tnode->set_attr( 'gram/gender', $info_ref->[0] );
    $tnode->set_attr( 'gram/number', $info_ref->[1] );
    $tnode->set_attr( 'gram/person', $info_ref->[2] );
    $tnode->set_attr( 'gram/politeness', $info_ref->[3] );

  }  

  # Other
  else {
    $tnode->set_gram_sempos('n.pron.indef');
  }

  return;
}

# Numerals
sub _number {
  my ( $tnode, $tag, $form, $lemma ) = @_;
  my $sempos = 'n';

  # TODO: this is probably not always correct
  $tnode->set_gram_sempos("$sempos.quant.def");

  # We propably cannot distinguish number of numerals
  $tnode->set_gram_number('sg');

  return;
}

# Verbs
# TODO: this sub was put together quite hastily, so it might not analyze verbs correctly
sub _verb {
    my ($tnode, $tag, $form, $lemma ) = @_;

    my $tense_hash = $tnode->wild->{tense};

    # constants
    $tnode->set_gram_sempos('v');
    $tnode->set_gram_iterativeness('it0');  # probably should not be constant
    $tnode->set_gram_resultative('res0'); # this shloud be checked too

    # negation
    if ( $tense_hash->{neg} ) {
        $tnode->set_gram_negation('neg1');
    }
    else {
        $tnode->set_gram_negation('neg0');
    }

    # gram_deontmod
    if ( $tense_hash->{deontmod} ) {
        $tnode->set_gram_deontmod($tense_hash->{deontmod});
    }
    else {
        $tnode->set_gram_deontmod('decl');
    }

    # gram_diathesis
    if ( $tense_hash->{pass} ) {
        $tnode->set_gram_diathesis('pas');
        $tnode->set_is_passive(1); # TODO ?
    }
    else {
        $tnode->set_gram_diathesis('act');
        $tnode->set_is_passive(undef); # TODO ?
    }
    
    # politeness
    # in PTD, politeness is only relevant to definite pronomial semantic pronouns
    # so right now, this information is not used

    # gram_dispmod
    $tnode->set_gram_dispmod('disp0');
    
    # gram_verbmod
    if ( $tense_hash->{cdn} ) {
      $tnode->set_gram_verbmod('cdn');
    }
    else {
      # TODO: do not ignore imperative
      $tnode->set_gram_verbmod('ind');
    }
  
    # gram_tense
    # TODO: can we detect future tense (for example from adverbial children?)
    if ( $tense_hash->{past} ) {
      $tnode->set_gram_tense('ant');
    }
    elsif ( $tense_hash->{pres} && $tense_hash->{perf} ) {
      $tnode->set_gram_tense('ant');
    }
    else {
      $tnode->set_gram_tense('sim');
    }
      
    return;
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2T::JA::SetGrammatemes

=head1 DESCRIPTION

Grammatemes of Japanese nodes are filled by this block, using
POS tags, info about auxiliary words, list of pronouns etc. Besides
the genuine grammatemes such as C<gram/number> or C<gram/tense>, also
the classification attribute C<gram/sempos> is filled.

=head1 AUTHORS

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

