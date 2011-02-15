package Treex::Block::T2T::EN2CS::TrLAddVariants;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

use ProbUtils::Normalize;

use TranslationModel::MaxEnt::Model;
use TranslationModel::Static::Model;

use TranslationModel::MaxEnt::FeatureExt::EN2CS;

use TranslationModel::Derivative::EN2CS::Numbers;
use TranslationModel::Derivative::EN2CS::Hyphen_compounds;
use TranslationModel::Derivative::EN2CS::Deverbal_adjectives;
use TranslationModel::Derivative::EN2CS::Deadjectival_adverbs;
use TranslationModel::Derivative::EN2CS::Nouns_to_adjectives;
use TranslationModel::Derivative::EN2CS::Verbs_to_nouns;
use TranslationModel::Derivative::EN2CS::Prefixes;
use TranslationModel::Derivative::EN2CS::Suffixes;
use TranslationModel::Derivative::EN2CS::Transliterate;

use TranslationModel::Combined::Backoff;
use TranslationModel::Combined::Interpolated;

use Lexicon::Czech;    # jen docasne, kvuli vylouceni nekonzistentnich tlemmat jako prorok#A

my $MODEL_MAXENT = 'data/models/translation/en2cs/tlemma_czeng09.maxent.pls.gz';
my $MODEL_STATIC = 'data/models/translation/en2cs/tlemma_czeng09.static.pls.gz';
my $MODEL_HUMAN  = 'data/models/translation/en2cs/tlemma_humanlex.static.pls.gz';

sub get_required_share_files {
    return ( $MODEL_MAXENT, $MODEL_STATIC, $MODEL_HUMAN );
}

my ( $combined_model, $max_variants );

sub BUILD {
    my $maxent_model = TranslationModel::MaxEnt::Model->new();
    $maxent_model->load("$ENV{TMT_ROOT}/share/$MODEL_MAXENT");

    my $static_model = TranslationModel::Static::Model->new();
    $static_model->load("$ENV{TMT_ROOT}/share/$MODEL_STATIC");

    my $humanlex_model = TranslationModel::Static::Model->new;
    $humanlex_model->load("$ENV{TMT_ROOT}/share/$MODEL_HUMAN");

    my $deverbadj_model = TranslationModel::Derivative::EN2CS::Deverbal_adjectives->new(  { base_model => $static_model } );
    my $deadjadv_model  = TranslationModel::Derivative::EN2CS::Deadjectival_adverbs->new( { base_model => $static_model } );
    my $noun2adj_model  = TranslationModel::Derivative::EN2CS::Nouns_to_adjectives->new(  { base_model => $static_model } );
    my $verb2noun_model = TranslationModel::Derivative::EN2CS::Verbs_to_nouns->new(       { base_model => $static_model } );
    my $numbers_model   = TranslationModel::Derivative::EN2CS::Numbers->new(              { base_model => 'not needed' } );
    my $compounds_model = TranslationModel::Derivative::EN2CS::Hyphen_compounds->new(     { base_model => 'not needed', noun2adj_model => $noun2adj_model } );
    my $prefixes_model  = TranslationModel::Derivative::EN2CS::Prefixes->new(             { base_model => $static_model } );
    my $suffixes_model  = TranslationModel::Derivative::EN2CS::Suffixes->new(             { base_model => 'not needed' } );
    my $translit_model  = TranslationModel::Derivative::EN2CS::Transliterate->new(        { base_model => 'not needed' } );
    my $static_translit = TranslationModel::Combined::Backoff->new(                       { models     => [ $static_model, $translit_model ] } );

    # make interpolated model
    my @interpolated_sequence = (
        { model => $maxent_model,    weight => 1 },
        { model => $static_translit, weight => 0.5 },
        { model => $humanlex_model,  weight => 0.1 },
        { model => $deverbadj_model, weight => 0.1 },
        { model => $deadjadv_model,  weight => 0.1 },
        { model => $noun2adj_model,  weight => 0.1 },
        { model => $verb2noun_model, weight => 0.1 },
        { model => $numbers_model,   weight => 0.1 },
        { model => $compounds_model, weight => 0.1 },
        { model => $prefixes_model,  weight => 0.1 },
        { model => $suffixes_model,  weight => 0.1 },
    );
    my $interpolated_model = TranslationModel::Combined::Interpolated->new( { models => \@interpolated_sequence } );

    #my @backoff_sequence = ( $interpolated_model, @derivative_models );
    #my $combined_model = TranslationModel::Combined::Backoff->new( { models => \@backoff_sequence } );
    $combined_model = $interpolated_model;
    return;
}

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $cs_troot = $bundle->get_tree('TCzechT');
    $max_variants = $self->get_parameter('MAX_VARIANTS') || 0;

    NODE:
    foreach my $cs_tnode ( $cs_troot->get_descendants() ) {

        # Skip nodes that were already translated by rules
        next if $cs_tnode->t_lemma_origin ne 'clone';

        #        next if $cs_tnode->t_lemma =~ /^\p{IsUpper}/;

        if ( my $en_tnode = $cs_tnode->src_tnode ) {

            my $features_hash_rf = TranslationModel::MaxEnt::FeatureExt::EN2CS::features_from_src_tnode($en_tnode);

            my $features_array_rf = [
                map           {"$_=$features_hash_rf->{$_}"}
                    sort grep { defined $features_hash_rf->{$_} }
                    keys %{$features_hash_rf}
            ];

            my $en_tlemma = $en_tnode->t_lemma;
            my @translations = $combined_model->get_translations( lc($en_tlemma), $features_array_rf );

            # !!! hack: odstraneni nekonzistentnich hesel typu 'prorok#A', ktera se objevila
            # kvuli chybne extrakci trenovacich vektoru z CzEngu u posesivnich adjektiv,
            # lepsi bude preanalyzovat CzEng a pretrenovat slovniky

            @translations = grep {
                not($_->{label} =~ /(.+)#A/
                    and Lexicon::Czech::get_poss_adj($1)
                    )
            } @translations;

            # POZOR, HACK, nutno resit jinak a jinde !!!
            # tokeny obsahujici pouze velka pismena a cisla se casto neprekladaji, pridaji se tedy mezi prekladove varianty
            if ($en_tlemma =~ /^[\p{isUpper}\d]+$/
                and $en_tlemma !~ /^(UN|VAT)$/
                and $en_tnode->get_lex_anode
                and $en_tnode->get_lex_anode->tag =~ /^NNP/
                )
            {
                unshift @translations, { 'label' => "$en_tlemma#N", 'source' => 'NNPs', 'prob' => 0.5 };
            }

            if ( $max_variants && @translations > $max_variants ) {
                splice @translations, $max_variants;
            }

            if (@translations) {

                if ( $translations[0]->{label} =~ /(.+)#(.)/ ) {
                    $cs_tnode->set_t_lemma($1);
                    $cs_tnode->set_attr( 'mlayer_pos', $2 );
                }
                else {
                    Report::fatal "Unexpected form of label: " . $translations[0]->{label};
                }

                $cs_tnode->set_attr(
                    't_lemma_origin',
                    ( @translations == 1 ? 'dict-only' : 'dict-first' )
                        .
                        "|" . $translations[0]->{source}
                );

                $cs_tnode->set_attr(
                    'translation_model/t_lemma_variants',
                    [   map {
                            $_->{label} =~ /(.+)#(.)/ or Report::fatal "Unexpected form of label: $_->{label}";
                            {   't_lemma' => $1,
                                'pos'     => $2,
                                'origin'  => $_->{source},
                                'logprob' => ProbUtils::Normalize::prob2binlog( $_->{prob} ),

                                #                           'backward_logprob' => _logprob( $_->{en_given_cs}, ),
                            }
                            } @translations
                    ]
                );

                #                print "\nSENTENCE:\t".$en_tnode->get_bundle->get_attr('english_source_sentence')."\n";
                #                print $en_tnode->t_lemma."\n";
                #                print "Original choice: ".$cs_tnode->t_lemma."\n";
                #                my ($first_tlemma) = split /\#/,$translations[0]->{label};
                #                if ($cs_tnode->t_lemma ne $first_tlemma) {
                #                    print "XXX Different\n";
                #                }
                #                else {
                #                    print "XXX Same\n";
                #                }
                #                foreach my $translation (@translations) {
                #                    print "$translation->{label}\t$translation->{prob}\n";
                #                }

            }
        }
    }
    return;
}

1;

__END__


=over

=item Treex::Block::T2T::EN2CS::TrLAddVariants

Adding t_lemma translation variants using the maxent
translation dictionary.

=cut

# Copyright 2010 Zdenek Zabokrtsky, David Marecek, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
