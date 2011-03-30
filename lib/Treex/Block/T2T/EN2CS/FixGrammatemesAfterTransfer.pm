package Treex::Block::T2T::EN2CS::FixGrammatemesAfterTransfer;
use utf8;
use Moose;
use Treex::Common;
extends 'Treex::Core::Block';

has 'ignore_negation' => (
    is            => 'ro',
    isa           => 'Bool',
    documentation => 'Do not try to fix cases like "ill"=>"mocný", "dangerous"=>"bezpečný".',
);

use Lexicon::Czech;

my $F1_FN = 'data/models/grammateme_transfer/en2cs/more_frequent_number_below_gov_noun.tsv';
my $F2_FN = 'data/models/grammateme_transfer/en2cs/more_frequent_number_for_noun_below_noun.tsv';
my $F3_FN = 'data/models/grammateme_transfer/en2cs/singular_given_noun_lemma.tsv';

sub get_required_share_files {
    return ( $F1_FN, $F2_FN, $F3_FN );
}

my %gov_lemma_to_number;
my %gov_lemma_dep_lemma_to_number;
my %prob_sg_given_lemma;

sub BUILD {

    # treatment of nouns in genitive positions with unclear gram/number (created from non-nouns or from n:attr)
    log_debug('Loading more probable genitive noun number below other noun');
    open my $F1, "<:utf8", "$ENV{TMT_ROOT}/share/$F1_FN" or log_fatal $!;
    while (<$F1>) {
        chomp;
        my ( $gov_lemma, $number ) = split /\t/;
        $gov_lemma_to_number{$gov_lemma} = $number;
    }

    open my $F2, "<:utf8", "$ENV{TMT_ROOT}/share/$F2_FN" or log_fatal $!;
    while (<$F2>) {
        chomp;
        my ( $gov_lemma, $dep_lemma, $number ) = split /\t/;
        $gov_lemma_dep_lemma_to_number{$gov_lemma}{$dep_lemma} = $number;
    }

    open my $F3, '<:utf8', "$ENV{TMT_ROOT}/share/$F3_FN" or log_fatal $!;
    while (<$F3>) {
        chomp;
        my ( $lemma, $prob ) = split /\t/;
        $prob_sg_given_lemma{$lemma} = $prob;
    }

    return;
}

sub more_frequent_number_for_genitive_noun_below_gov_noun {
    my ( $gov_noun, $dep_noun ) = @_;

    my $short_number = $gov_lemma_dep_lemma_to_number{$gov_noun}{$dep_noun}
        || $gov_lemma_to_number{$gov_noun} || return undef;

    #   print "XXX: $gov_noun $dep_noun $short_number\n";

    if ( $short_number eq "P" ) {
        return 'pl';
    }
    else {
        return 'sg';
    }
}

# self-test
#foreach my $entry ('produkce vejce','poslanec parlamentu','ministr finance','ministr vnitro','olgoj chorchoj') {
#    my ($gov,$dep) = split / /,$entry;
#    print join " ",($gov,$dep,more_frequent_number_for_genitive_noun_below_gov_noun($gov,$dep));
#    print "\n";
#}
# end of genitives

sub process_tnode {
    my ( $self, $cs_t_node ) = @_;
    my $en_t_node  = $cs_t_node->src_tnode or return;
    my $cs_formeme = $cs_t_node->formeme;
    my $en_formeme = $en_t_node->formeme;
    my $en_tlemma  = $en_t_node->t_lemma;
    my $cs_tlemma  = $cs_t_node->t_lemma;

    # Some English clause heads may become non-heads and vice versa
    $cs_t_node->set_attr( 'is_clause_head', $cs_formeme =~ /n:pokud_jde_o.4|v.+(fin|rc)/ ? 1 : 0 );

    # defaultne: you --> plural
    if ( ( $cs_t_node->get_attr('gram/person') || "" ) eq "2" ) {
        $cs_t_node->set_attr( 'gram/number', 'pl' )
    }

    # default gender with 1st and 2nd person: masculine animate
    if ( ( $cs_t_node->get_attr('gram/person') || "" ) =~ /[12]/ ) {
        $cs_t_node->set_attr( 'gram/gender', 'anim' )
    }

    # defaultni rod u pluralu bude muzsky zivotny
    if ($cs_tlemma eq '#PersPron'
        and ( ( $cs_t_node->get_attr('gram/number') || '' ) eq 'pl' )
        and ( ( $cs_t_node->get_attr('gram/gender') || '' ) =~ /^(|nr)$/ )
        )
    {
        $cs_t_node->set_attr( 'gram/gender', 'anim' );
    }

    if ( $cs_formeme =~ /^n/ and $en_formeme !~ /^n/ ) {
        $cs_t_node->set_attr( 'gram/sempos', 'n.denot' );
        $cs_t_node->set_attr( 'gram/number', 'sg' );
        foreach my $gram (qw(degcmp verbmod deontmod tense aspect resultative dispmod iterativeness person)) {
            $cs_t_node->set_attr( "gram/$gram", undef );
        }
    }

    # egg production -> vyroba vajec  (plural may appear with a noun if moved to postmodification genitive)
    if ($cs_formeme eq "n:2"
        and $en_formeme =~ /^(n:attr|[^n])/
        and not $cs_t_node->get_parent->is_root
        and ( $cs_t_node->get_attr('gram/number') || '' ) eq 'sg'
        and $cs_t_node->get_parent->formeme =~ /^n/
        )
    {

        #	    print "before ".$cs_t_node->get_parent->t_lemma."\t".$cs_t_node->t_lemma."\tbefore: ".
        #		$cs_t_node->get_attr('gram/number')."\t";
        my $predicted_number =
            more_frequent_number_for_genitive_noun_below_gov_noun( $cs_t_node->get_parent->t_lemma, $cs_tlemma );

        if (( $cs_t_node->get_parent->get_attr('gram/number') || '' ) eq 'pl'
            and $en_tlemma !~ /\p{IsUpper}/
            and defined $prob_sg_given_lemma{$cs_tlemma}
            and $prob_sg_given_lemma{$cs_tlemma} < 0.8
            )
        {
            $predicted_number = "pl";

            #		print "QQQ\t".$cs_t_node->get_parent->t_lemma."\t".$cs_t_node->t_lemma."\n";
        }

        $cs_t_node->set_attr( 'gram/number', $predicted_number || 'sg' );

        #	    print "after: ".$cs_t_node->get_attr('gram/number')."\n";
    }

    # Force gram/number of lemmas with strict inclination to sg. resp. pl. according to CNK corpus
    if ( $cs_formeme =~ /^n/ and defined $prob_sg_given_lemma{$cs_tlemma} ) {

        #!!! optimalizace parametru?
        if ( $prob_sg_given_lemma{$cs_tlemma} > 0.98 ) {

            # However, don't force singular for nodes modified by numeral > 1
            if ( !grep { ( Lexicon::Czech::number_for( $_->t_lemma ) || 0 ) > 1 } $cs_t_node->get_children() ) {
                $cs_t_node->set_attr( 'gram/number', 'sg' );
            }
        }
        elsif ( $prob_sg_given_lemma{$cs_tlemma} < 0.05 ) {
            $cs_t_node->set_attr( 'gram/number', 'pl' );
        }
    }

    if ( $en_tlemma =~ /^(this|that|what)$/ and $cs_formeme =~ /^n/ ) {
        $cs_t_node->set_attr( "gram/gender", 'neut' );    # should be shifted rather to synthesis???
    }

    # everybody -> lemma=všechen form=všichni
    if ( $en_tlemma eq 'everybody' && $cs_tlemma =~ /^vš/ ) {
        $cs_t_node->set_attr( "gram/number", 'pl' );
    }

    # everybody -> lemma=každý, somebody -> někdo,...
    elsif ( $en_tlemma =~ /^(some|no|any|every)(one|body)$/ and $cs_formeme =~ /^n/ ) {
        $cs_t_node->set_attr( "gram/gender", 'anim' );
        if ( $cs_tlemma eq "všechen" ) {                 # "vsichni" indeed
            $cs_t_node->set_attr( "gram/number", 'pl' );
        }
        else {
            $cs_t_node->set_attr( "gram/number", 'sg' );
        }
    }

    if ( !$self->ignore_negation ) {

        # !!! tohle by chtelo premistit spis do Fix_negation
        # regexpy jsou tu kvuli tomu, aby byly pokryty ruzne derivaty tehoz korenu
        if (( $en_tlemma    =~ /^absen/    and $cs_tlemma =~ /^pří/ )    # v angl. negace lexikalizovana, v cestine tvaroslovna
            or ( $en_tlemma =~ /^recent/   and $cs_tlemma =~ /^dáv/ )
            or ( $en_tlemma =~ /^necess/   and $cs_tlemma =~ /^zbytn/ )
            or ( $en_tlemma =~ /^ill/      and $cs_tlemma =~ /^moc/ )
            or ( $en_tlemma =~ /^near/     and $cs_tlemma =~ /^dalek/ )
            or ( $en_tlemma =~ /^innoc/    and $cs_tlemma =~ /^vin/ )
            or ( $en_tlemma =~ /^danger/   and $cs_tlemma =~ /^bezp/ )
            or ( $en_tlemma =~ /^risk/     and $cs_tlemma =~ /^bezp/ )
            or ( $en_tlemma =~ /^disadv/   and $cs_tlemma =~ /^výh/ )
            or ( $en_tlemma =~ /^annoy/    and $cs_tlemma =~ /^příj/ )
            or ( $en_tlemma =~ /^harmless/ and $cs_tlemma =~ /^škod/ )
            or ( $en_tlemma =~ /^disgust/  and $cs_tlemma =~ /^chutn/ )
            or ( $en_tlemma =~ /^idle/     and $cs_tlemma =~ /^čin/ )
            or ( $en_tlemma eq 'regardless' and $cs_tlemma =~ /^závisl/ )
            or ( $cs_tlemma eq 'dbalý' )
            or ( $en_tlemma =~ /^fail/       and $cs_tlemma =~ /^zdař/ )
            or ( $en_tlemma =~ /^hat/        and $cs_tlemma =~ /^snáš/ )
            or ( $en_tlemma =~ /^rememb/     and $cs_tlemma =~ /^zapom/ )
            or ( $en_tlemma =~ /^innocent/   and $cs_tlemma =~ /^vinn/ )
            or ( $en_tlemma =~ /^immed/      and $cs_tlemma =~ /^prodl/ )
            or ( $en_tlemma =~ /^wrong/      and $cs_tlemma =~ /^správ/ )
            or ( $en_tlemma =~ /^hazard/     and $cs_tlemma =~ /^bezp/ )
            or ( $en_tlemma =~ /^essent/     and $cs_tlemma =~ /^zbyt/ )
            or ( $en_tlemma =~ /^advers/     and $cs_tlemma =~ /^žádou/ )
            or ( $en_tlemma =~ /^advers/     and $cs_tlemma =~ /^přízn/ )
            or ( $en_tlemma =~ /^vague/      and $cs_tlemma =~ /^určit/ )
            or ( $en_tlemma =~ /^vague/      and $cs_tlemma =~ /^jasn/ )
            or ( $en_tlemma =~ /^unfavour/   and $cs_tlemma =~ /^příz/ )
            or ( $en_tlemma =~ /^requir/     and $cs_tlemma =~ /^zbyt/ )
            or ( $en_tlemma =~ /^opti/       and $cs_tlemma =~ /^povin/ )
            or ( $en_tlemma =~ /^need/       and $cs_tlemma =~ /^zbyt/ )
            or ( $en_tlemma =~ /^ignor/      and $cs_tlemma =~ /^vším/ )
            or ( $en_tlemma =~ /^hostil/     and $cs_tlemma =~ /^přát/ )
            or ( $en_tlemma =~ /^fail/       and $cs_tlemma =~ /^usp/ )
            or ( $en_tlemma =~ /^void/       and $cs_tlemma =~ /^platn/ )
            or ( $en_tlemma =~ /^tremend/    and $cs_tlemma =~ /^uvěř/ )
            or ( $en_tlemma =~ /^forget/     and $cs_tlemma =~ /^pamat/ )
            or ( $en_tlemma =~ /^disturb/    and $cs_tlemma =~ /^příj/ )
            or ( $en_tlemma =~ /^uneasy/     and $cs_tlemma =~ /^příj/ )
            or ( $en_tlemma =~ /^merciless/  and $cs_tlemma =~ /^(milosr|úpros)/ )
            or ( $en_tlemma =~ /^slopp/      and $cs_tlemma =~ /^(dbal|pořád)/ )
            or ( $en_tlemma =~ /^discontent/ and $cs_tlemma =~ /^(spokoj)/ )
            )
        {
            $cs_t_node->set_attr( 'gram/negation', 'neg1' );
        }
    }

    # plural should be filled with t-lemma 'procento', since it behaves like a normal noun in Czech
    if ( $cs_tlemma eq 'procento' ) {
        CHILDREN: foreach my $en_child ( $en_t_node->get_descendants() ) {
            my $alex = $en_child->get_lex_anode;
            if (defined $alex
                and $alex->tag eq 'CD'
                and $alex->lemma !~ /^(one|[01](\.\d+)?)$/
                )
            {
                $cs_t_node->set_attr( 'gram/number', 'pl' );
                last CHILDREN;
            }
        }
    }

    # pluralia tantum - podstatna jmena pomnozna (chovaji se jako plural)
    if ( Lexicon::Czech::is_plural_tantum( lc $cs_tlemma ) ) {
        $cs_t_node->set_attr( 'gram/number', 'pl' );
    }

    # staff -> lemma=zaměstnanec --> plural
    if ( $en_tlemma eq 'staff' && $cs_tlemma eq "zaměstnanec" ) {
        $cs_t_node->set_attr( "gram/number", 'pl' );
    }

    # nouns that are typically in plural in English but in singular in Czech
    # (list semiautomatically collected from Czeng train00)
    # !!! regexpy by to chtelo nahradit eq, kde to jde
    if (( $en_t_node->get_attr('gram/number') || "" ) eq "pl"
        and ( $cs_t_node->get_attr('gram/sempos') || "" ) =~ /^n/
        and (
            ( $en_tlemma    =~ /^goods/      and $cs_tlemma =~ /^zboží/ )
            or ( $en_tlemma =~ /^setting/    and $cs_tlemma =~ /^nastavení/ )
            or ( $en_tlemma =~ /^sales/      and $cs_tlemma =~ /^prodej/ )
            or ( $en_tlemma =~ /^efforts/    and $cs_tlemma =~ /^úsilí/ )
            or ( $en_tlemma =~ /^contents/   and $cs_tlemma =~ /^obsah/ )
            or ( $en_tlemma =~ /politics/    and $cs_tlemma =~ /ika$/ )             # mozna i dalsi
            or ( $en_tlemma =~ /^policy/     and $cs_tlemma =~ /^politika/ )
            or ( $en_tlemma =~ /^vegetables/ and $cs_tlemma =~ /^zelenina/ )
            or ( $en_tlemma =~ /^wood/       and $cs_tlemma =~ /^les/ )
            or ( $en_tlemma =~ /^insect/     and $cs_tlemma =~ /^hmyz/ )
            or ( $en_tlemma =~ /^means/      and $cs_tlemma =~ /^prostř/ )
            or ( $en_tlemma =~ /^lot/        and $cs_tlemma =~ /^spousta/ )
            or ( $en_tlemma =~ /^fishery/    and $cs_tlemma =~ /^rybolov/ )
            or ( $en_tlemma =~ /^personnel/  and $cs_tlemma =~ /^person/ )
            or ( $en_tlemma =~ /^dish/       and $cs_tlemma =~ /^nadobí/ )
            or ( $en_tlemma =~ /^thanks/     and $cs_tlemma =~ /^poděkování/ )
            or ( $en_tlemma =~ /^seeds/      and $cs_tlemma =~ /^osivo/ )
            or ( $en_tlemma =~ /^people/     and $cs_tlemma =~ /^národ/ )
        )
        )
    {
        $cs_t_node->set_attr( 'gram/number', 'sg' );
    }

    # ... and the opposite case: sg goes to pl
    if (( $en_t_node->get_attr('gram/number') || "" ) eq "s"
        and ( $cs_t_node->get_attr('gram/sempos') || "" ) =~ /^n/
        and (
            ( $en_tlemma    =~ /^money/       and $cs_tlemma =~ /^pení/ )
            or ( $en_tlemma =~ /^both/        and $cs_tlemma =~ /^oba/ )
            or ( $en_tlemma =~ /^legislation/ and $cs_tlemma =~ /^předp/ )
            or ( $en_tlemma =~ /^staff/       and $cs_tlemma =~ /^zaměst/ )
            or ( $en_tlemma =~ /^hair/        and $cs_tlemma =~ /^vlasy/ )
            or ( $en_tlemma =~ /^knowledge/   and $cs_tlemma =~ /^znalost/ )
            or ( $en_tlemma =~ /^staff/       and $cs_tlemma =~ /^pracovník/ )
            or ( $en_tlemma =~ /^interest/    and $cs_tlemma =~ /^úrok/ )
            or ( $en_tlemma =~ /^toolbar/     and $cs_tlemma =~ /^nástroje/ )
            or ( $en_tlemma =~ /^cereal/      and $cs_tlemma =~ /^obiloviny/ )
            or ( $en_tlemma =~ /^news/        and $cs_tlemma =~ /^zpráva/ )
            or ( $en_tlemma =~ /^expenditure/ and $cs_tlemma =~ /^náklad/ )
            or ( $en_tlemma =~ /^beard/       and $cs_tlemma =~ /^vous/ )
        )
        )
    {
        $cs_t_node->set_attr( 'gram/number', 'pl' );
    }

    # unfortunately -> nanestesti (not generated by morphological generator)
    if ($en_tlemma                                eq "fortunately"
        and $cs_tlemma                            eq "naštěstí"
        and $cs_t_node->get_attr('gram/negation') eq 'neg1'
        )
    {
        $cs_t_node->set_attr( 'gram/negation', 'neg0' );
        $cs_t_node->set_t_lemma('naneštěstí');
    }

    # asymetry in degcmp
    if (( $en_tlemma eq 'previously' and $cs_tlemma eq 'dřív' )
        or ( $en_tlemma eq 'farther' and $cs_tlemma eq 'daleko' )
        )
    {
        $cs_t_node->set_attr( 'gram/degcmp', 'comp' );
    }

    if ( ( $en_tlemma eq 'first' and $cs_tlemma eq 'brzy' ) ) {
        $cs_t_node->set_attr( 'gram/degcmp', 'sup' );
    }

    # deleting grammatemes that became superfluous due to change of sempos
    if ( $cs_formeme !~ /^v/ ) {
        $cs_t_node->set_voice(undef);
        $cs_t_node->set_is_passive(undef);
    }

    return;
}

1;

=over

=item Treex::Block::T2T::EN2CS::FixGrammatemesAfterTransfer

This block changes some grammatemes and other attributes
which became inappropriate after the lexeme/formeme transfer
(for example, voice disappears when part of
speech is changed from verb to noun, number disappears
if noun is changed to verb, etc.).

=back

=cut

# Copyright 2008-2010 Zdenek Zabokrtsky, Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
