package SEnglishT_to_TCzechT::Translate_LF_joint_static;

use 5.008;
use strict;
use warnings;
use utf8;
use Readonly;

use base qw(TectoMT::Block);

use TranslationModel::Static::Model;

my $MODEL_STATIC = 'data/models/translation/en2cs/jointLF_czeng09.static.pls.gz';

sub get_required_share_files {
    return ( $MODEL_STATIC );
}

my ( $model );

sub BUILD {
    $model = TranslationModel::Static::Model->new();
    $model->load("$ENV{TMT_ROOT}/share/$MODEL_STATIC");
    return;
}


sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $cs_troot = $bundle->get_tree('TCzechT');

  NODE:
    foreach my $cs_tnode ( $cs_troot->get_descendants() ) {

        # Skip nodes that were already translated by rules
        next NODE if ($cs_tnode->get_attr('formeme_origin')||"") !~ /clone|dict/
            or ($cs_tnode->get_attr('t_lemma_origin')||"") !~ /clone|dict/;

        if ( my $en_tnode = $cs_tnode->get_source_tnode() ) {

            # only prepositional groups
            next NODE if $en_tnode->get_attr('formeme') !~ /n:.+\+/;

            my $input_label = $en_tnode->get_attr('t_lemma')."|".$en_tnode->get_attr('formeme');
            next NODE if $input_label =~ /\?/;

            if (my ($translation) = $model->get_translations( $input_label )) {

                my ($output_label,$formeme) = split /\|/,$translation->{label};

                my ($lemma, $pos) = split /#/, $output_label;

               my $old_lemma =  $cs_tnode->get_attr('t_lemma');
                my $old_formeme =  $cs_tnode->get_attr('formeme');

                if ($pos !~ /[XC]/
                        and $formeme !~ /\?/
                            and ($lemma ne $cs_tnode->get_attr('t_lemma')
                                 or $formeme ne $cs_tnode->get_attr('formeme'))) {

                    $cs_tnode->set_attr('t_lemma', $lemma);
                    $cs_tnode->set_attr('mlayer_pos', $pos);
                    $cs_tnode->set_attr('t_lemma_origin', 'joint-static');

                    $cs_tnode->set_attr('formeme', $formeme);
                    $cs_tnode->set_attr('formeme_origin', 'joint-static' );

#                    print "QQQQ  $input_label ---> $formeme $lemma # $pos      instead of $old_formeme $old_lemma\n";
                }

            }
        }
    }
    return;
}

1;

__END__


=over

=item SEnglishT_to_TCzechT::Translate_LF_joint_static

Joint unigram static translation of lemmas and formemes (first only).
Used only for prepositional groups (which are less dependent on the context).

=cut

# Copyright 2010 Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
