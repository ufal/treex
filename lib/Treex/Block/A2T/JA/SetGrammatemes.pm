package Treex::Block::A2T::JA::SetGrammatemes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

Readonly my $DEBUG => 0;

#------ Constants --------
# Some tags should not appear on the t-layer:
# Particles, symbols, etc.
# We take first two tag levels so we can distinguish between nouns, numerals and pronouns
Readonly my %SUB_FOR_TAG => (
  'Keiyōshi-Jiritsu'          => \&_adj,
  #setsubi?
  'Keiyōshi-HiJiritsu'        => \&_adj,
  'Dōshi-Jiritsu'             => \&_verb,
  #setsubi?
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

# TODO: there should not be that many #PersPron
Readonly my %PERSPRON_INFO => (

);



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
    my $form = lc $lex_anode->form;

    $tag =~ s{^([^\-]+)\-([^\-]+)\-[^\-]+\-[^\-]+}{$1\-$2}g;

    my $sub_ref = $SUB_FOR_TAG{$tag};
    if ( defined $sub_ref ) {
      $sub_ref->( $tnode, $tag, $form );
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
  my ( $tnode, $tag, $form ) = @_;
  $tnode->set_gram_sempos('n.denot');
  
  # Japanese words do not explicitly express gramatical number (since this knowledge can be extracted from the context), but we would like to set it anyway
  # as a default, we set number to 'sg'
  my $number = 'sg';
  # TODO: depending on the context, set the number correctly

  # we use only simple heuristic now
  $number = 'pl' if (_has_numeral_child($tnode));

  $tnode->set_gram_number($number);

  return;  
}

sub _has_numeral_child {
  my ($tnode) = @_;
  return grep { $_->get_lex_anode->tag =~ /Kazu/ } $tnode->get_children();
}

# Adjectives
sub _adj {
  my ( $tnode, $tag, $form ) = @_;

  $tnode->set_gram_sempos('adj.denot');
  $tnode->set_gram_negation('neg0');

  $tnode->set_gram_degcmp('pos');
  # TODO: can we do something about setting gram/degcmp?

  return;
}

# Adverbs
sub _adv {
  my ( $tnode, $tag, $form ) = @_;
  
  # all Japanese adverbs should be impossible to negate, however there are adverbs used only with negative predicate
  # TODO: is that really correct?
  $tnode->set_gram_sempos('adv.denot.grad.nneg'); 
  $tnode->set_gram_negation('neg0');

  $tnode->set_gram_degcmp('pos');
  # TODO: degcmp - similar situation as in _adj

  return;
}

# Pronouns
sub _pron {

  ### TODO ###

  return;
}

# Numerals
sub _number {
  my ( $tnode, $tag, $form ) = @_;
  my $sempos = 'n';

  # TODO: this is probably not always correct
  $tnode->set_gram_sempos("$sempos.quant.def");

  # We propably do not distinguish number of numerals
  $tnode->set_gram_number('sg');

  return;
}

# Verbs
sub _verb {
    my ($tnode, $tag, $form ) = @_;

    ### TODO ###

    $tnode->set_gram_sempos('v');

    ### This is now obstolete
    # negative copulas will probably not be set right
    #my @negation_nodes = map { $_->form eq "ない" || $_->form eq "ん" } 
    #                        $tnode->get_aux_anodes();
    #
    #if (scalar @negation_nodes == 0) {
    #    $tnode->set_gram_negation('neg1');
    #}
    #else {
    #    $tnode->set_gram_negation('neg0');
    #}
    return;
}

1;

=over

=item Treex::Block::A2T::JA::SetGrammatemes

Negation grammmatemes of Japanese verb nodes are filled by this block, using
POS tags and info about auxiliary words. Sempos is also set for verbs,
because it is needed to generate negative forms correctly after transfer

TODO: set other grammatemes too, mainly:
    - degcmp
    - politeness
    - tense
    - verbmod
... and maybe others

=back

=cut

=head1 AUTHORS

Dusan Varis
