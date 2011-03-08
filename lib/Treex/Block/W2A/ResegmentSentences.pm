package Treex::Block::W2A::ResegmentSentences;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

use Segmentation::en::RuleBased;

sub process_bundle {
    my ( $self, $bundle ) = @_;

    log_fatal 'At this moment, this block is applicable only on English (tentatively)'
        if $self->language ne 'en';

    my $zone = $bundle->get_zone( $self->language, $self->selector );
    log_fatal 'The bundle does not contain a ' . $self->_doczone_name if !$bundle;

    log_fatal $bundle->_zone_name . ' contains no "sentence" attribute'
        if !defined $zone->sentence;

    my @sentences = Segmentation::en::RuleBased::get_sentences($zone->sentence);

    if (@sentences > 1) {
        log_info 'Splitting sentence: '.$zone->sentence;
        my $doc = $bundle->get_document;
        $zone->set_sentence($sentences[0]);
        foreach my $i (reverse (1..$#sentences)) {
            my $new_bundle = $doc->create_bundle( { after => $bundle } );
            my $new_bundle_zone = $new_bundle->create_zone( $self->language, $self->selector );
            $new_bundle_zone->set_sentence($sentences[$i]);
            $new_bundle->set_id($new_bundle->id."_merge_with_prev");
        }
    }
}


1;

__END__

=over

=item Treex::Block::W2A::ResegmentSentences

If the sentence segmenter says that the current sentence is
actually composed of two or more sentences, then new bundles
are inserted after the current bundle, each containing just
one piece of the resegmented original sentence.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
