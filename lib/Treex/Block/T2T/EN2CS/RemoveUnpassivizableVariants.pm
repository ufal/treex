package Treex::Block::T2T::EN2CS::RemoveUnpassivizableVariants;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';


use Report;
use List::Util qw(first);

use LanguageModel::MorphoLM;
my $morphoLM;

sub BUILD {
    $morphoLM = LanguageModel::MorphoLM->new() if !$morphoLM;
}


sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $cs_troot = $bundle->get_tree('TCzechT');

    foreach my $cs_tnode ( $cs_troot->get_descendants() ) {

        next if ($cs_tnode->get_attr('t_lemma_origin')||"") !~ /^dict-first/;

        if ($cs_tnode->is_passive) {

            my $variants_ref = $cs_tnode->get_attr('translation_model/t_lemma_variants');

            my @compatible = grep {$_->{pos} ne "V" or _is_passivizable($_->{t_lemma},$cs_tnode)}
                map {$_->{t_lemma} =~ s/_s[ie]//; $_} # reflexive particles must disappear during passivization
                    @{$variants_ref};

            if (@compatible and @compatible < @{$variants_ref}) {
                my $old_tlemma = $cs_tnode->t_lemma;
                my $new_tlemma = $compatible[0]->{t_lemma};
                if ($old_tlemma ne $new_tlemma) {
#                    print "old_tlemma=$old_tlemma\tnew_tlemma=$new_tlemma\ten_sentence: ".$bundle->get_attr('english_source_sentence')."\t".$bundle->get_attr('czech_target_sentence')."\t".$cs_tnode->get_fposition()."\n";
                    $cs_tnode->set_attr('t_lemma', $compatible[0]->{t_lemma});
                    $cs_tnode->set_attr('mlayer_pos', $compatible[0]->{pos});
                }
                $cs_tnode->set_attr('translation_model/t_lemma_variants', \@compatible);
            }

        }
    }
    return;
}

sub _is_passivizable {
    my ($lemma,$node) = @_;
    return $morphoLM->forms_of_lemma($lemma, {tag_regex => '^Vs'});
}


1;

__END__

=over

=item Treex::Block::T2T::EN2CS::RemoveUnpassivizableVariants

If a finite verb t-node should be in passive voice, all verb variants that
cannot be passivized are removed (prior to variant selection).
'Passivizability' is decided according to C<LanguageModel::MorphoLM>
which is trained on SYN corpus.
(Using passivizability according to morphological generator leads to overgeneration).

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky, Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
