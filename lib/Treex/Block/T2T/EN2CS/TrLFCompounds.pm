package Treex::Block::T2T::EN2CS::TrLFCompounds;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Lexicon::CS;
use Treex::Tool::EnglishMorpho::Lemmatizer;
use Treex::Tool::Tagger::TnT;

my $tagger;

use Treex::Tool::TranslationModel::Static::Model;
use Treex::Tool::TranslationModel::Derivative::EN2CS::Deverbal_adjectives;
use Treex::Tool::TranslationModel::Derivative::EN2CS::Deadjectival_adverbs;
use Treex::Tool::TranslationModel::Derivative::EN2CS::Nouns_to_adjectives;
use Treex::Tool::ML::NormalizeProb;

my $MODEL_STATIC = 'data/models/translation/en2cs/tlemma_czeng09.static.pls.slurp.gz';
my ( $static_model, $deverbadj_model, $deadjadv_model, $noun2adj_model );

sub get_required_share_files { return $MODEL_STATIC; }

my $lemmatizer = Treex::Tool::EnglishMorpho::Lemmatizer->new();

sub BUILD {

    return;
}

sub process_start {
    $static_model = Treex::Tool::TranslationModel::Static::Model->new();
    $static_model->load( Treex::Core::Resource::require_file_from_share($MODEL_STATIC) );
    $deverbadj_model = Treex::Tool::TranslationModel::Derivative::EN2CS::Deverbal_adjectives->new( { base_model => $static_model } );
    $deadjadv_model = Treex::Tool::TranslationModel::Derivative::EN2CS::Deadjectival_adverbs->new( { base_model => $static_model } );
    $noun2adj_model = Treex::Tool::TranslationModel::Derivative::EN2CS::Nouns_to_adjectives->new( { base_model => $static_model } );

    $tagger = Treex::Tool::Tagger::TnT->new({model=>'data/models/tagger/tnt/en/wsj', tntargs=>''});
    return;
}

sub process_tnode {
    my ( $self, $node ) = @_;

    # Process untranslated (i.e. "cloned" from source tnode) lemmas
    return if $node->t_lemma_origin ne 'clone';

    # that look like a compound (contain a dash, but no uppercase).
    return if $node->t_lemma !~ /[a-z]\-[a-z]/;
    return if $node->t_lemma =~ /[A-Z]/;

    # Try to translate it as two or more t-nodes.
    my @forms = split( /\-/, $node->t_lemma );
    my @tags = @{ $tagger->tag_sentence( \@forms ) };

    SUBWORD:
    while (@forms) {
        my $form = shift @forms;
        my $tag  = shift @tags;

        # prepositions and determiners (that are not at the end of the compound) are not translated
        next SUBWORD if $tag =~ /^(IN|TO|DT)$/ && @forms;

        my ($lemma) = $lemmatizer->lemmatize( $form, $tag );

        my @translations = (
            $static_model->get_translations( lc($lemma) ),
            $deverbadj_model->get_translations( lc($lemma) ),
            $deadjadv_model->get_translations( lc($lemma) ),
            $noun2adj_model->get_translations( lc($lemma) ),
        );

        # rules
        if ( $lemma eq 'ex' ) {
            @translations = ( { label => 'bývalý#A', 'prob' => 0.5, 'origin' => 'rule-Translate_LF_compounds' } );
        }
        elsif ( $lemma eq 'credit' ) {
            @translations = ( { label => 'kreditní#A', 'prob' => 0.5, 'origin' => 'rule-Translate_LF_compounds' } );
        }

        my @t_lemma_variants;
        foreach my $tr (@translations) {
            if ( $tr->{label} =~ /(.+)#(.)/ ) {
                push @t_lemma_variants, {
                    't_lemma'          => $1,
                    'pos'              => $2,
                    'origin'           => $tr->{source},
                    'logprob'          => Treex::Tool::ML::NormalizeProb::prob2binlog( $tr->{prob} ),
                    'backward_logprob' => -1,
                };
            }
        }

        if ( !@t_lemma_variants ) {
            @t_lemma_variants = (
                {   't_lemma'          => $form,
                    'pos'              => 'X',
                    'origin'           => 'clone-Tranalste_LF_compounds',
                    'logprob'          => '-1',
                    'backward_logprob' => -1,
                }
            );
        }

        if ( !@t_lemma_variants ) {
            log_warn('Something is rotten in the state of Translate_LF_compounds');
            next SUBWORD;
        }

        # If translating non-last sub-word of the compound,
        # create new child node.
        if (@forms) {
            my $new_formeme = $tag =~ /^D/ ? 'adv:' : 'adj:attr';
            my $new_node = $node->create_child(
                {
                    't_lemma'                            => $t_lemma_variants[0]->{t_lemma},
                    't_lemma_origin'                     => 'dict-first-Translate_LF_compounds',
                    'nodetype'                           => 'complex',
                    'functor'                            => '???',
                    'gram/sempos'                        => 'adj.denot',
                    'formeme'                            => $new_formeme,
                    'formeme_origin'                     => 'rule-Translate_LF_compounds',
                    'translation_model/t_lemma_variants' => [@t_lemma_variants],
                }
            );
            $new_node->shift_before_node( $node, { without_children => 1 } );
            my $en_t_node = $node->src_tnode;
            $new_node->set_src_tnode($en_t_node);
        }

        # If translating the last sub-word of the compound,
        # save the translation into the original t_node.:
        else {
            $node->set_t_lemma( $t_lemma_variants[0]->{t_lemma} );
            $node->set_t_lemma_origin('dict-first-Translate_LF_compounds');
            $node->set_attr( 'translation_model/t_lemma_variants', [@t_lemma_variants] );
        }
    }
    return;
}

1;

=encoding utf8

=over

=item Treex::Block::T2T::EN2CS::TrLFCompounds

Tries to translated compounds like I<ex-commander> to two or more t-nodes.
This block should go after other blocks that add t-lemma translation variants
(e.g. B<SEnglishT_to_TCzechT::Translate_L_add_variants>), so it tries to translate
only the nodes which were not translated so far.

=back

=cut

# Copyright 2010 David Marecek, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
