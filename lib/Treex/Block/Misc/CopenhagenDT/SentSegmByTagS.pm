package Treex::Block::Misc::CopenhagenDT::SentSegmByTagS;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_bundle {
    my ( $self, $bundle ) = @_;

    if (not $bundle->get_document->file_stem =~ /(\d{4})/){
        log_warn "4-digit CDT number cannot be determined from the file name";
        return;
    }
    my $number = $1;

  ZONE:
    foreach my $zone ($bundle->get_all_zones) {

        my $language = $zone->language;
        next ZONE if $language =~ /(da|en)/;
        next ZONE if $bundle->get_document->wild->{annotation}{$language}{syntax}
            or $bundle->get_document->wild->{annotation}{$language}{segmented};

        $bundle->get_document->wild->{annotation}{$language}{segmented} = 'tag_s';

        my $a_root = $zone->get_atree;
        my @nodes = $a_root->get_descendants;

        my $current_sent_number = -1;
        my $first_node_in_sentence;

        foreach my $node ( @nodes ) {

            next ZONE if not defined $node->wild->{sent_number};

            if ($node->wild->{sent_number} == $current_sent_number) {
                $node->set_parent($first_node_in_sentence);
            }

            else {
                $current_sent_number = $node->wild->{sent_number};
                $first_node_in_sentence = $node;
            }
        }
    }
    return;
}



1;

=over

=item Treex::Block::Misc::CopenhagenDT::SentSegmByTagS

Sentence segmentation according to <s> tags in the original
*.tag files (very unreliable).

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
