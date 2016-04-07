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

  INDEX:
    foreach my $da_index (0..$#{$nodes{da}}) {

        my $before_newline;

        # sentence end detection
        if ($da_index==$#{$nodes{da}} # last token in the file

                or ( $da_index < $#{$nodes{da}} and $da_index > 0 and
                        ($nodes{da}[$da_index+1]->wild->{space}||'') =~ /000a/ and do {$before_newline = 1})

                    or ($nodes{da}[$da_index]->form eq '.')
            ) {

            my $da_sentence_end_node = $nodes{da}[$da_index];
            my $en_sentence_end_node;

            if ( $da_index == $#{$nodes{da}} ) { # if it's the last token in Danish, let's go to the last English token too
                $en_sentence_end_node = $nodes{en}[-1];
            }

            else { # otherwise we search for the English boundary by alignment
                my ($nodes_rf, $types_rf) = $da_sentence_end_node->get_directed_aligned_nodes;
                if ($nodes_rf) {
                    ($en_sentence_end_node) = @$nodes_rf;
                }

                else { # last resort: try to find the sentence end in English completely independently of alignment
                    ($en_sentence_end_node) = map {$nodes{en}[$_]} grep {
                        $nodes{en}[$_]->form eq '.'
                            or ( $_ < $#{$nodes{en}} and ($nodes{en}[$_+1]->wild->{space}||'') =~ /000a/)
                    } ($prev_sent_end_index{en}+1..$#{$nodes{en}});
                }
            }

            if (not defined $en_sentence_end_node) {
                log_warn "Detected sentence-end token was not aligned: ".
                    $da_sentence_end_node->form . ' '. $da_sentence_end_node->id." . Sentence boundary not made here.";
                next INDEX;
            }

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

                if ($end_index eq $prev_sent_end_index{en}) {
                    log_warn "Sentence end index not found, language=$language,  start_index $start_index  English end node: ".$en_sentence_end_node->id."\n";
                }

#                print "lang=$language start=$start_index end=$end_index\n";

                my $new_zone = $new_bundle->create_zone($language);
                my $new_atree =  $new_zone->create_atree;

                foreach my $index ($start_index..$end_index) {
                    $nodes{$language}[$index]->set_parent($new_atree);

                }

                $prev_sent_end_index{$language} = $end_index;
            }
        }
    }

    if (grep {$_->get_atree->get_descendants} $bundle->get_all_zones) {
        log_warn "All nodes should have been distributed into new bundles, nothing can remain in the first bundle";
    }
    else {
        $bundle->remove();
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

# Copyright 2012 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
