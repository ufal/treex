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

    my @all_langs = sort keys %$gold_aligns;
    my $align_info = {};
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
            merge_align_info($align_info, $partial_info);
        }
    }
    return $align_info;
}

sub merge_align_info {
    my ($merged_ai, $new_ai, $node) = @_;
    foreach my $lang (keys %$new_ai) {
        my $old_value = $merged_ai->{$lang};
        my $new_value = $new_ai->{$lang};
        if (!defined $old_value || ($new_value =~ /\Q$old_value\E/)) {
            $merged_ai->{$lang} = $new_value;
        }
        elsif ($old_value !~ /\Q$new_value\E/) {
            log_warn "The align_info wild attribute already set for language $lang in one of the nodes gold-aligned to ".(defined $node ? $node->id : "???").". Merging it with a new value.";
            $merged_ai->{$lang} .= "\t".$new_value;
        }
    }
}

1;
