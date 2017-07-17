package Treex::Block::Coref::Project::MentionsFromAtoTlayer;
use Moose;
use Treex::Core::Common;
use Data::Printer;

use Treex::Tool::Coreference::NodeFilter;

extends 'Treex::Core::Block';

sub process_document {
    my ($self, $doc) = @_;

    my @atrees = map {$_->get_tree($self->language, 'a', $self->selector)} $doc->get_bundles;

    my $all_mentions_count = 0;
    my $projected_mentions_count = 0;

    my %last_ante = ();
    foreach my $atree (@atrees) {
        my %start_entities = ();
        my %end_entities = ();
        foreach my $anode ($atree->get_descendants({ordered => 1})) {

            my @start_ents = @{$anode->wild->{coref_mention_start} // []};
            my @end_ents = @{$anode->wild->{coref_mention_end} // []};
            next if (!@start_ents && !@end_ents);
            
            foreach my $start_ent (@start_ents) {
                my $sq = $start_entities{$start_ent};
                if (!defined $sq) {
                    $sq = [];
                }
                push @$sq, $anode;
                $start_entities{$start_ent} = $sq;
            }
            foreach my $end_ent (@end_ents) {
                my $eq = $end_entities{$end_ent};
                if (!defined $eq) {
                    $eq = [];
                }
                push @$eq, $anode;
                $end_entities{$end_ent} = $eq;
            }
        }

        log_warn "Different entity numbers for openings and closings: ".$atree->get_address
            if ((join " ", sort keys %start_entities) ne (join " ", sort keys %end_entities));
        foreach my $ent (keys %start_entities) {
            my $sq = $start_entities{$ent};
            my $eq = $end_entities{$ent};
            log_warn "Different number of openings and closing of entities: ".$atree->get_address if (@$sq != @$eq);
            for (my $i = 0; $i < @$sq; $i++) {
                $all_mentions_count++;
                my $anaph = $self->project_mention_to_tlayer($sq->[$i], $eq->[$i]);
                next if (!defined $anaph);
                $projected_mentions_count++;
                my $ante = $last_ante{$ent};
                if (defined $ante) {
                    $anaph->add_coref_text_nodes($ante);
                }
                $last_ante{$ent} = $anaph;
            }
        }
    }
    print STDERR "Projected mentions: $projected_mentions_count / $all_mentions_count\n";
}

sub project_mention_to_tlayer {
    my ($self, $s_anode, $e_anode) = @_;
    return if (!defined $s_anode || !defined $e_anode);
    my @anodes_between = $s_anode->get_nodes_between($e_anode);
    my @t_head_cands = grep {defined $_} map {$_->get_referencing_nodes('a/lex.rf')} ($s_anode, @anodes_between, $e_anode);
    my @t_head_nouns = grep {Treex::Tool::Coreference::NodeFilter::matches($_, ['all_anaph_corbon17'])} @t_head_cands;
    my @t_head_depth_sorted = sort {$a->get_depth <=> $b->get_depth} @t_head_nouns;
    return if (!@t_head_depth_sorted);
    return $t_head_depth_sorted[0];
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Coref::Project::MentionsFromAtoTlayer

=head1 DESCRIPTION

A block to transfer coreference annotated as mentions and entities
using "coref_mention_start" and "coref_mention_end" wild attributes
from the a-layer to the PDT-like annotation of coreference on the
t-layer.

This block has been copied from the project-specific extensions of Treex
for the CORBON 2017 Shared Task project.

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
