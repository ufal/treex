package Treex::Tool::Align::Annot::Util;

use Moose;
use Treex::Core::Common;

sub get_gold_aligns {
    my ($node, $other_langs, $align_type) = @_;
    my %gold_aligns = map {
        my ($ali_nodes, $ali_types) = $node->get_undirected_aligned_nodes({ 
            language => $_, 
            selector => $node->selector, 
            rel_types => [$align_type],
        });
        $_ => $ali_nodes;
    } @$other_langs;
    $gold_aligns{$node->language} = [$node];
    return \%gold_aligns;
}

sub get_align_info {
    my ($gold_aligns) = @_;

    my @all_langs = keys %$gold_aligns;
    my $align_info;
    foreach my $lang (@all_langs) {
        foreach my $align_node (@{$gold_aligns->{$lang}}) {
            my $partial_info = $align_node->wild->{align_info};
            next if (!defined $partial_info);
            if (!ref($partial_info)) {
                my ($other_lang) = grep {$_ ne $lang} @all_langs;
                $partial_info = {
                    $other_lang => $partial_info,
                };
            }
            foreach my $part_lang (keys %$partial_info) {
                if (defined $align_info->{$part_lang}) {
                    log_warn "The align_info wild attribute already set for language $part_lang in one of the nodes gold-aligned to ".$align_node->id.". Overwriting it with a new value.";
                }
                $align_info->{$part_lang} = $partial_info->{$part_lang};
            }
        }
    }
    return $align_info;
}

1;
