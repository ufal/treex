package Treex::Block::Misc::Translog::SegmentSentences;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_document {
    my ( $self, $document ) = @_;

    my ($bundle) = $document->get_bundles;

    my %nodes;
    my %prev_sent_end_index;

    foreach my $language (qw(da en)) {
        $nodes{$language} = [ $bundle->get_zone($language)->get_atree->get_children ];
        $prev_sent_end_index{$language} = -1;
    }

    foreach my $da_index (0..$#{$nodes{da}}) {

        my $before_newline;

        # sentence end detection
        if ($da_index==$#{$nodes{da}} # last token in the file

                or ( $da_index < $#{$nodes{da}} and $da_index > 0 and
                        ($nodes{da}[$da_index+1]->wild->{space}||'') =~ /000a/ and do {$before_newline = 1})

                    or ($nodes{da}[$da_index]->form eq '.')
            ) {

            my $da_sentence_end_node = $nodes{da}[$da_index];

            my ($nodes_rf, $types_rf) = $da_sentence_end_node->get_aligned_nodes;
            my ($en_sentence_end_node) = @$nodes_rf;

            my $new_bundle= $document->create_bundle;
            foreach my $language (qw(da en)) {

                my $start_index =$prev_sent_end_index{$language}+1;

                my $end_index;
                if ($language eq 'da') {
                    $end_index = $da_index;
                }

                elsif ($before_newline) {
                    ($end_index) = grep {$_ > 0 and ($nodes{en}[$_]->wild->{space}||'')=~ /000a/ } ($prev_sent_end_index{en}..$#{$nodes{en}});
                    if ( $end_index > -1 ) {
                        $end_index--;
                    }
                    else {
                        log_fatal "Line break was expected in the second language too\n";
                    }
                }

                else {
                    ($end_index) = grep {$nodes{en}[$_] eq $en_sentence_end_node} ($prev_sent_end_index{en}..$#{$nodes{en}});
                }

#                print "lang=$language start=$start_index end=$end_index\n";

                my $new_zone = $new_bundle->create_zone($language);
                my $new_atree =  $new_zone->create_atree;

                my $ord;
                foreach my $index ($start_index..$end_index) {
                    $ord++;
                    $nodes{$language}[$index]->set_parent($new_atree);

                }

                $prev_sent_end_index{$language} = $end_index;
            }
        }
    }
    return;
}

1;

=over

=item Treex::Block::Misc::Translog::SegmentSentences

Sentence segmentation specific for Translog data.

=back

=cut

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
