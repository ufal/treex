package Treex::Block::Filter::CzEng::DictionaryRatio;
use Moose;
use Treex::Core::Common;
use TranslationDict::EN2CSAlt;
use TranslationDict::SimplePOS;
use Treex::Block::Filter::CzEng::Common;

extends 'Treex::Block::Filter::CzEng::Common';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my @en = $bundle->get_zone('en')->get_atree->get_descendants;
    my @cs = $bundle->get_zone('cs')->get_atree->get_descendants;

    my %cs_lemmas = map {
        my $lemma = $_->get_attr("lemma");    # get lemma
        $lemma =~ s/[_-].*$//;                # only keep the base form
        lc($lemma) => 1;
    } @cs;

    my $covered = 0;                          # number of English words covered in Czech

    my $dict = TranslationDict::EN2CSAlt->new();
    my $has_translation = 0;

    for my $en_node (@en) {
        my $en_lemma      = lc( $en_node->get_attr("lemma") );
        my $en_tag_simple = TranslationDict::SimplePOS::tag2simplepos( $en_node->get_attr("tag"), "ptb" );
        my @trans         = $dict->get_translations( $en_lemma, $en_lemma, $en_tag_simple );
        $has_translation++ if @trans;
        $covered++ if grep { $cs_lemmas{"$_"} } map { lc $_->{"cs_tlemma"} } @trans;
    }

    my $reliable = "";# $has_translation >= 5 ? "reliable_" : "rough_";
    my @bounds = ( 0, 0.2, 0.5, 0.8, 1 );

    $self->add_feature( $bundle, $reliable . "dictratio="
        . $self->quantize_given_bounds( $covered / $has_translation, @bounds ) );

    return 1;
}

1;

=over

=item Treex::Block::Filter::CzEng::DictionaryRatio

=back

A filtering feature. Computes the ratio of English words whose
translations appear in the Czech side based on translation dictionary.
Check is case insensitive.

=cut

# Copyright 2011 Ales Tamchyna

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
