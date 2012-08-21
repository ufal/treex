package Treex::Block::Misc::Translog::MoveAlignedTargetNodes;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_document {
    my ( $self, $document ) = @_;

    my @bundles = $document->get_bundles;
    my $first_bundle = shift @bundles;
    my $SourceLanguage = $document->wild->{annotation}{sourceLanguage};
    my $bundle = $first_bundle;

  ZONE:
    foreach my $zone ($first_bundle->get_all_zones) {

        my $language = $zone->language;
printf STDERR "AAA1: %s\t%s\n", $language, $SourceLanguage;
        if($language eq $SourceLanguage) {next;}
        my $selector = $zone->selector; 

printf STDERR "AAA2: %s\n", $selector;
      NODE:
        foreach my $node ( $zone->get_atree->get_children ) {
            my @anodes = $node->get_aligned_nodes_of_type("alignment");
            foreach my $anode (@anodes) {
              printf STDERR "AAAA: %s\t%s\n", $anode->get_bundle()->id(), $bundle->id();

#              my $zone_tgt = $bundle->create_zone($language, $selector);
#              my $root_tgt = $zone_tgt->create_atree;



            }
        }

    }

    return;
}

1;

=over

=item Treex::Block::Misc::Translog::SegmentSentences

Sentence segmentation specific for Translog data.
TODO: now hardwired for English and Danish, should be universal
(but how to detect which language is the central one?)

=back

=cut

# Copyright 2012 Michael Carl 
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
