package Treex::Block::T2T::EN2CS::TrLFJointStatic;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use TranslationModel::Static::Model;

my $MODEL_STATIC = 'data/models/translation/en2cs/jointLF_czeng09.static.pls.slurp.gz';

sub get_required_share_files {
    return ($MODEL_STATIC);
}

has model => ( is => 'rw', builder => 'build_model' );

sub build_model {
    my $self  = shift;
    my $model = TranslationModel::Static::Model->new();
    $model->load("$ENV{TMT_ROOT}/share/$MODEL_STATIC");
    return $model;
}

sub process_tnode {
    my ( $self, $cs_tnode ) = @_;

    # Skip nodes that were already translated by rules
    return if ( $cs_tnode->formeme_origin || '' ) !~ /clone|dict/
        or ( $cs_tnode->t_lemma_origin || '' ) !~ /clone|dict/;

    my $en_tnode = $cs_tnode->src_tnode or return;

    # only prepositional groups
    return if $en_tnode->formeme !~ /n:.+\+/;

    my $input_label = $en_tnode->t_lemma . "|" . $en_tnode->formeme;
    return if $input_label =~ /\?/;

    my ($translation) = $self->model->get_translations($input_label) or return;

    my ( $output_label, $formeme ) = split /\|/, $translation->{label};

    my ( $lemma, $pos ) = split /#/, $output_label;

    my $old_lemma   = $cs_tnode->t_lemma;
    my $old_formeme = $cs_tnode->formeme;

    if ($pos !~ /[XC]/
        && $formeme !~ /\?/
        && ( $lemma ne $cs_tnode->t_lemma or $formeme ne $cs_tnode->formeme )
        )
    {
        $cs_tnode->set_t_lemma($lemma);
        $cs_tnode->set_attr( 'mlayer_pos', $pos );
        $cs_tnode->set_t_lemma_origin('joint-static');

        $cs_tnode->set_formeme($formeme);
        $cs_tnode->set_formeme_origin('joint-static');
    }
    return;
}

1;

__END__


=over

=item Treex::Block::T2T::EN2CS::TrLFJointStatic

Joint unigram static translation of lemmas and formemes (first only).
Used only for prepositional groups (which are less dependent on the context).

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
