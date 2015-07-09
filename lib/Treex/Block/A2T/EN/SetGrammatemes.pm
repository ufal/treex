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

# modal verb -> gram/deontmod mapping
Readonly my %DEONTMOD_FOR_LEMMA => (
    'must'   => 'deb',
    'should' => 'hrt',
    'ought'  => 'hrt',
    'want'   => 'vol',
    'can'    => 'poss',
    'cannot' => 'poss', # TODO can this still appear?
    'could'  => 'poss',
    'may'    => 'perm',
    'might'  => 'perm',
    'be_able_to' => 'fac',
    'have_to' => 'deb',
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
    'one' => '-S3',
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

        if ( $tnode->get_coref_gram_nodes() ) {
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
    # Numerals "two", "three", ... "ninty" should be annotated as plural.
    # I am not sure about years (e.g. "1997 was a nice year."), probably they should be singular.
    my $number = Treex::Tool::Lexicon::EN::number_for($form) || 0;
    if ($number >= 100) {#( $form =~ /^(hundred|thousand|million|billion)$/ ) {
        my $plural = _has_numeral_child_needed_for_plural($tnode);
        $tnode->set_attr( 'gram/number', $plural ? 'pl' : 'sg' );
    } elsif ( $number >= 2) { #&& $number < 100) {
        $tnode->set_gram_number('pl');
    }
    return;
}

# verbs are fully analyzed in SetTense:
# here, the grammatemes get filled based on tnode->wild->{tense}
sub _verb {
    my ( $tnode, $tag, $form ) = @_;

    my $tense_hash = $tnode->wild->{tense};

    # constants
    $tnode->set_gram_sempos('v');
    $tnode->set_gram_iterativeness('it0');
    $tnode->set_gram_resultative('res0');

    # negation
    if ( $tense_hash->{neg} ) {
        $tnode->set_gram_negation('neg1');
    }
    else {
        $tnode->set_gram_negation('neg0');
    }

    # gram_deontmod
    if ( $tense_hash->{modal} ) {
        # TODO use DEONTMOD_FOR_LEMMA
        $tnode->set_gram_deontmod($tense_hash->{modal});
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

    if ( $tense_hash->{inf} ) {

        # infinitives have no dispmod and verbmod
        $tnode->set_gram_dispmod('nil');
        $tnode->set_gram_verbmod('nil');

        # but the infinitive can also be past or future
        # TODO there are many possibilities here...
        if ( $tense_hash->{past} ) {
            # $tnode->set_gram_tense('nil');
            $tnode->set_gram_tense('ant');
        }
        elsif ( $tense_hash->{fut} ) {
            # $tnode->set_gram_tense('nil');
            $tnode->set_gram_tense('post');
        }
        else {
            $tnode->set_gram_tense('nil');
        }
    }
    else {

        # gram_dispmod
        $tnode->set_gram_dispmod('disp0');

        # gram_verbmod
        if ( $tense_hash->{cdn} ) {
            $tnode->set_gram_verbmod('cdn');
        }
        else {
            # ignores imp - which is now set later in FixImperatives
            $tnode->set_gram_verbmod('ind');
        }

        # gram_tense
        if ( $tense_hash->{fut} ) {
            $tnode->set_gram_tense('post');
        }
        elsif ( $tense_hash->{past} ) {
            $tnode->set_gram_tense('ant');
        }
        elsif ( $tense_hash->{pres} && $tense_hash->{perf} ) {
            $tnode->set_gram_tense('ant');
        }
        else {
            # ignores imperatives – fixed later in FixImperatives
            $tnode->set_gram_tense('sim'); 
        }
    }

    return;
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

# Copyright 2008-2013 Zdenek Zabokrtsky, Martin Popel, Rudolf Rosa

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
