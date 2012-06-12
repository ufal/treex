package Treex::Block::A2T::EN::SetGrammatemes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::EN;

Readonly my $DEBUG => 0;

#------ Constants --------
# Some tags should not appear on the t-layer:
#  DET determiners, MD modal verbs (can, should,...), POS possesive 's,
#  EX existential there, + various punctuation tags
Readonly my %SUB_FOR_TAG => (
    NN => \&_noun, NNS => \&_noun, NNP => \&_noun, NNPS => \&_noun, '$' => \&_noun,
    JJ => \&_adj, JJR => \&_adj, JJS => \&_adj,
    PRP => \&_perspron, 'PRP$' => \&_perspron,
    WP  => \&_o_pron,   WRB    => \&_o_pron, WDT => \&_o_pron, DT => \&_o_pron, 'WP$' => \&_o_pron,
    CD  => \&_number,   PDT    => \&_number,                                                                 # PDT= half, all?, quite?, ...
    VB  => \&_verb,     VBP    => \&_verb, VBZ => \&_verb, VBG => \&_verb, VBD => \&_verb, VBN => \&_verb,
    RB => \&_adv, RBR => \&_adv, RBS => \&_adv,
);

# Some modal verb -> gramm/deontmod mapping
# ("have to" and "be able to" is handled separately,
#  "shall" is not handled at all.)
Readonly my %DEONTMOD_FOR_LEMMA => (
    'must'   => 'deb',
    'should' => 'hrt',
    'ought'  => 'hrt',
    'want'   => 'vol',
    'can'    => 'poss',
    'cannot' => 'poss',
    'could'  => 'poss',
    'may'    => 'perm',
    'might'  => 'perm',
);

# $form => $gender . $number . $person
Readonly my %PERSPRON_INFO => (
    'i'   => '-S1', 'my'   => '-S1', 'myself'   => '-S1', 'me'    => '-S1',
    'you' => '--2', 'your' => '--2', 'yourself' => '-S2', 'yours' => '--2',
    'he'  => 'MS3', 'his'  => 'MS3', 'himself'  => 'MS3', 'him'   => 'MS3',
    'she' => 'FS3', 'her'  => 'FS3', 'herself'  => 'FS3',
    'it'  => 'NS3', 'its'  => 'NS3', 'itself'   => 'NS3',
    'we' => '-P1', 'our' => '-P1', 'ourselves' => '-P1', 'us' => '-P1', 'ours' => '-P1',
    'yourselves' => '-P2',
    'they' => '-P3', 'their' => '-P3', 'themselves' => '-P3', 'them' => '-P3', 'theirs' => '-P3',
);

Readonly my %TECTO_NAME_FOR => (
    'F' => 'fem', 'M' => 'anim', 'N' => 'neut',
    'S' => 'sg',  'P' => 'pl',
    '1' => '1',   '2' => '2',    '3' => '3',
    '-' => 'nr',
);

Readonly my %TECTO_PERSON_INFO =>
    map { ( $_ => _get_tecto_info( $PERSPRON_INFO{$_} ) ) } keys %PERSPRON_INFO;

sub _get_tecto_info {
    my ($gender_number_person) = @_;
    my ( $gender, $number, $person ) = split( //, $gender_number_person );
    my @tecto_info = @TECTO_NAME_FOR{ ( $gender, $number, $person ) };
    return \@tecto_info;
}

#------ Main loop --------
sub process_tnode {
    my ( $self, $t_node ) = @_;
    return if $t_node->nodetype ne 'complex';

    # Sempos of all complex nodes should be defined,
    # so initialize it with a default value.
    $t_node->set_gram_sempos('???');

    assign_grammatemes_to_tnode($t_node);
    return;
}

sub assign_grammatemes_to_tnode {
    my ($tnode) = @_;
    my $lex_anode = $tnode->get_lex_anode();
    return if !$lex_anode;
    my $tag  = $lex_anode->tag;
    my $form = lc $lex_anode->form;

    # Choose an appropriate sub according to the tag
    my $sub_ref = $SUB_FOR_TAG{$tag};
    if ( defined $sub_ref ) {
        $sub_ref->( $tnode, $tag, $form );
    }
    elsif ( $DEBUG and all { $_ ne $tag } qw(: '' ``) ) {
        warn "Grammatems not assigned to: $form\t$tag\n";
    }

    if ( _is_negated($tnode) ) {
        $tnode->set_gram_negation('neg1');
    }

    return;
}

#------ Subs for each POS --------
sub _noun {
    my ( $tnode, $tag, $form ) = @_;
    $tnode->set_gram_sempos('n.denot');
    my $number = $tag =~ /S$/ ? 'pl' : 'sg';

    # Some lemmas have same singular as plural and tag is not reliable
    if ( $form eq 'euro' && _has_numeral_child_needed_for_plural($tnode) ) {
        $number = 'pl';
    }
    $tnode->set_gram_number($number);
    return;
}

sub _has_numeral_child_needed_for_plural {
    my ($tnode) = @_;
    return any {
        ( Treex::Tool::Lexicon::EN::number_for( $_->t_lemma ) || 0 ) > 1;
    }
    $tnode->get_children();
}

# Adjectives
sub _adj {
    my ( $tnode, $tag, $form ) = @_;
    my %is_aux_form = map { ( lc( $_->form ) => 1 ) } $tnode->get_aux_anodes();

    $tnode->set_gram_sempos('adj.denot');
    $tnode->set_gram_negation('neg0');

    my $degree = $tag eq 'JJS' || $is_aux_form{'most'}
        ? 'sup'
        : $tag eq 'JJR' || $is_aux_form{'more'} ? 'comp'
        :                                         'pos';
    $tnode->set_gram_degcmp($degree);
    return;
}

# Adverbs
sub _adv {
    my ( $tnode, $tag, $form ) = @_;
    my %is_aux_form = map { ( lc( $_->form ) => 1 ) } $tnode->get_aux_anodes();

    $tnode->set_gram_sempos('adv.denot.grad.neg');
    $tnode->set_gram_negation('neg0');

    my $degree = $tag eq 'RBS' || $is_aux_form{'most'}
        ? 'sup'
        : $tag eq 'RBR' || $is_aux_form{'more'} ? 'comp'
        :                                         'pos';
    $tnode->set_gram_degcmp($degree);
    return;
}

# Personal pronouns
sub _perspron {
    my ( $tnode, $tag, $form ) = @_;
    $tnode->set_gram_sempos('n.pron.def.pers');
    if ( $form =~ /sel(f|ves)$/ ) {
        $tnode->set_attr( 'is_reflexive', 1 );
    }

    my $info_ref = $TECTO_PERSON_INFO{$form};

    if ( !defined $info_ref ) {
        warn "No morpho info for: $form\t$tag\n" if $DEBUG;
        $info_ref = [ 'nr', 'nr', 'nr' ];
    }

    $tnode->set_attr( 'gram/gender', $info_ref->[0] );
    $tnode->set_attr( 'gram/number', $info_ref->[1] );
    $tnode->set_attr( 'gram/person', $info_ref->[2] );

    return;
}

# Other pronouns (not personal)
sub _o_pron {
    my ( $tnode, $tag, $form ) = @_;

    if ( any { $_ eq $form } qw(when where why how) ) {
        $tnode->set_gram_sempos('adv.pron.indef');
    }
    else {

        # "what(sempos=n) is this" vs. "what(sempos=adj) colour is it"
        # !!! doresit - podle toho, jestli neni nalevo nahore sem. substantivum
        $tnode->set_gram_sempos('n.pron.indef');

        if ( any { $form eq $_ } qw(those these both) ) {
            $tnode->set_gram_number('pl');
        }
        else {
            $tnode->set_gram_number('sg');
        }

        if ( $tnode->get_attr('coref_gram.rf') ) {
            $tnode->set_gram_indeftype('relat');
        }
    }
    return;
}

sub _number {
    my ( $tnode, $tag, $form ) = @_;
    my $sempos = ( $form =~ /^[^\/]*((fir|1)st|(seco|2)nd|(thi|3)rd|th)$/ ) ? 'adj' : 'n';
    $tnode->set_gram_sempos("$sempos.quant.def");

    # Plural of hundred can be in English both "hundreds" and "hundred".
    # This should be distinguished already on the m-layer, but for
    # numerals (tag=CD) there is no analogy to NN/NNS tags.
    # Similarly for thousand, million and billion.
    if ( $form =~ /^(hundred|thousand|million|billion)$/ ) {
        my $plural = _has_numeral_child_needed_for_plural($tnode);
        $tnode->set_attr( 'gram/number', $plural ? 'pl' : 'sg' );
    }
    return;
}

sub _verb {
    my ( $tnode, $tag, $form ) = @_;
    my @aux_anodes   = $tnode->get_aux_anodes();
    my %is_aux_form  = map { ( lc( $_->form ) => 1 ) } @aux_anodes;
    my %is_aux_lemma = map { ( $_->lemma => 1 ) } @aux_anodes;

    my ($deontmod) = grep { defined $_ } ( map { $DEONTMOD_FOR_LEMMA{ $_->lemma } } @aux_anodes );
    my $negated = any { $is_aux_form{$_} } qw(not n't cannot);

    $tnode->set_gram_sempos('v');
    $tnode->set_gram_iterativeness('it0');
    $tnode->set_gram_resultative('res0');
    $tnode->set_attr( 'gram/negation', $negated ? 'neg1' : 'neg0' );

    # First guess deontic modality...
    $tnode->set_attr( 'gram/deontmod', $deontmod || 'decl' );

    # ...and then correct "have to"...
    if ( all { $is_aux_lemma{$_} } qw(have to) ) {
        ## but filter our e.g. "It appears to have grown."
        my $a_have = first { $_->lemma eq 'have' } @aux_anodes;
        my $a_to   = first { $_->lemma eq 'to' } @aux_anodes;
        if ( $a_have->ord + 1 == $a_to->ord ) {
            $tnode->set_gram_deontmod('deb');
        }
    }

    # ...and "be able to".
    if ( all { $is_aux_lemma{$_} } qw(be able to) ) {
        $tnode->set_gram_deontmod('fac');
        if ( $is_aux_form{unable} ) {
            ##TODO: negace významových sloves vs. modálních není v TectoMT (ale ani ve FGD) dořešena
            $tnode->set_gram_negation('neg1');
        }
    }

    # First, we will process infinitives...
    if ( !$tnode->is_clause_head ) {

        $tnode->set_gram_tense('nil');
        $tnode->set_gram_verbmod('nil');
        $tnode->set_gram_dispmod('nil');

        # ...because it's easy and we are quickly finished :-)
        return;
    }

    # So now we deal with a finite verb
    $tnode->set_gram_dispmod('disp0');

    # Verbal modality is quite straightforward...
    my $is_conditional = any { $is_aux_lemma{$_} } qw(would could should might);

    # There is also an imperative modality, but see sub _add_sentmod().
    $tnode->set_attr( 'gram/verbmod', $is_conditional ? 'cdn' : 'ind' );

    # ... but gram/tense is more intricate
    #    my $tense = _guess_verb_tense( $tnode, $tag, \%is_aux_form, \%is_aux_lemma );
    my $tense = _guess_verb_tense($tnode);
    $tnode->set_gram_tense($tense);

    return;
}

sub _guess_verb_tense {
    my ($tnode) = @_;

    my @anodes = grep { $_->tag =~ /^(V|MD)/ }
        $tnode->get_anodes( { ordered => 1 } );

    my @forms = map { lc( $_->form ) } @anodes;
    my @tags  = map { $_->tag } @anodes;

    return 'post' if any {/^(will|shall|wo)$/} @forms;

    return 'post' if any { $_ eq "going" } @forms[ 0 .. $#forms - 1 ];    # 'to be going to ...'

    return 'ant' if $tags[0] =~ /VB[DN]/                                  # VBN allowed only because of frequent tagging errors VBD->VBN
            or ( any { $_ =~ /^(have|has|'ve|having)$/ } @forms[ 0 .. $#forms - 1 ] and any { $_ =~ /VB[ND]/ } @tags );

    return 'sim';
}

#------ Other subs --------

#ZZ:
# trosku hackozni osetrni negace (behem lematizace se ztratil rozdil mezi
# independent a dependent, viz PEDT::MorphologyAnalysis; ted je ale potreba mit ho v gramatemu negation)
#MP:
# EnglishMorpho::Lemmatizer now returns informations about negations
# TODO (MP): update scheme, put there negation on m-level, delete this hacking sub
sub _is_negated {
    my ($tnode) = @_;
    my $sempos = $tnode->gram_sempos;
    return 0 if !defined $sempos or $sempos !~ /^(n|adj|adv)\.denot/;

    my $t_lemma = lc( $tnode->t_lemma ) || '';
    my $m_form = lc( $tnode->get_lex_anode()->form );
    if ( $m_form =~ /^(un|in|im|non|dis|il|ir)-?(..)/ ) {
        my $expected_prefix = $2;
        if ( $t_lemma =~ /^\Q$expected_prefix\E/ ) {

            # escaping \Q necessary for word 'Disk\/Trend' which gets
            # lemmatized to k\/Tred

            # print STDERR "--- nalezena negace: $m_form $t_lemma\n";
            return 1;
        }
    }
    return 0;
}

1;

=over

=item Treex::Block::A2T::EN::SetGrammatemes

Grammatemes of English complex nodes are filled by this block, using
POS tags, info about auxiliary words, list of pronouns etc. Besides
the genuine grammatemes such as C<gram/number> or C<gram/tense>, also
the classification attribute C<gram/sempos> is filled.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
