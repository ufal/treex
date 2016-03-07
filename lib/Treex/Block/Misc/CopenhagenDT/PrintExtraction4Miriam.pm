package Treex::Block::Misc::CopenhagenDT::PrintExtraction4Miriam;

use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'language' => (is => 'rw', default=>'de');

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my %node2new_ord;
    foreach my $language ('da',$self->language) {
        return if not $bundle->get_zone($language);
        my $tree = $bundle->get_zone($language)->get_atree;
        my $ord;
        foreach my $node ($tree->get_descendants({ordered=>1})) {
            $ord++;
            $node2new_ord{$node} = $ord;
        }
        print "$language sentence:\t",(join ' ',map {$_->form} $tree->get_descendants({ordered=>1})),"\n";
    }

    my $da_atree = $bundle->get_zone('da')->get_atree;
    my $second_lang_atree = $bundle->get_zone($self->language)->get_atree;

    my $alignments = '';
    foreach my $second_lang_node ($second_lang_atree->get_descendants) {
        my ($alignment_links_rf, $alignment_types_rf) = $second_lang_node->get_directed_aligned_nodes;
        if ($alignment_links_rf) {
            my @da_indices;

            foreach my $i (0..$#$alignment_links_rf) {
                if ($alignment_types_rf->[$i] eq 'alignment') {
                    my $da_index = $node2new_ord{$alignment_links_rf->[$i]};
                    if ($da_index) {# if not, then the links points to other sentence
                        push @da_indices, $da_index;
                    }
                }

            }

            if (@da_indices) {
                $alignments .= (join ',', @da_indices)
                    .'-'.$node2new_ord{$second_lang_node}." ";
            }
        }
    }

    $alignments =~ s/ $//;
    print "alignments:\t$alignments\n\n";

    return;
}



1;

=over

=item Treex::Block::Misc::CopenhagenDT::PrintExtraction4Miriam

Print Danish-German alignments for Miriam Kaeshammer, roughly according to her description:

>>>So here is a what I need: The goal is to extract the word alignments
>>> from Danish to the other available languages. Let's say we are
>>> interested in the Danish-German alignments for now.
>>>
>>> for each Danish tree t1 {
>>>       if t1 is aligned to a German tree t2 {
>>>           print the terminal nodes t1_i of t1
>>>           print the terminal nodes t2_j of t2
>>>           go through the terminal nodes t1_i of t1 {
>>>               if t1_i is aligned to t2_j {
>>>                   print i-j
>>>               }
>>>           }
>>>       }
>>> }
>>>

=back

=cut

# Copyright 2013 Zdenek Zabokrtsky
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
