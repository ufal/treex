package Treex::Block::A2A::FlowNetwork;
use Moose;
use Treex::Core::Common;
use Graph;
use Graph::Directed;
use Graph::MaxFlow;

extends 'Treex::Core::Block';

has 'to_language' => ( is => 'rw', isa => 'Str', default => '' );
has 'to_selector' => ( is => 'rw', isa => 'Str', default => '' );

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $source_tree = $bundle->get_tree( $self->language, 'a', $self->selector);
    my $target_tree = $bundle->get_tree( $self->to_language, 'a', $self->to_selector);
    my $network = Graph::Directed->new;
    my @source_nodes = $source_tree->get_descendants();
    my @target_nodes = $target_tree->get_descendants();
    return if @source_nodes < 2 || @target_nodes < 2;
    foreach my $node (@source_nodes) {
        my $ord = $node->ord;
        print $node->form."\n" if !defined $node->wild()->{'mst_score'};
        my @scores = @{$node->wild()->{'mst_score'} || [0]};
        foreach my $to_ord (0 .. $#scores) {
            next if $ord == $to_ord;
            $network->add_weighted_edge("se$ord", "sn$ord", $scores[$to_ord]);
            $network->add_weighted_edge("se$ord", "sn$to_ord", $scores[$to_ord]);
            $network->add_weighted_edge("s", "se$ord", 2*$scores[$to_ord]);
        }
        my ($alinodes, $alitypes) = $node->get_aligned_nodes();
        foreach my $n (0 .. $#$alinodes) {
            my $target_ord = $$alinodes[$n]->ord;
            my $weight = $$alitypes[$n] =~ /left/ ? 0.5 : 0;
            $weight += $$alitypes[$n] =~ /right/ ? 0.5 : 0;
            $network->add_weighted_edge("sn$ord", "tn$target_ord", $weight);
        }
    }
    foreach my $node (@target_nodes) {
        my $ord = $node->ord;
        my @scores = @{$node->wild()->{'mst_score'} || [0]};
        foreach my $to_ord (0 .. $#scores) {
            next if $ord == $to_ord;
            $network->add_weighted_edge("tn$ord", "te$ord", $scores[$to_ord]);
            $network->add_weighted_edge("tn$to_ord", "te$ord", $scores[$to_ord]);
            $network->add_weighted_edge("te$ord", "t", 2*$scores[$to_ord]);
        }
    }
    my $maxflow = Graph::MaxFlow::max_flow($network, "s", "t");
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::FlowNetwork

=head1 AUTHOR

David Marecek <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.


