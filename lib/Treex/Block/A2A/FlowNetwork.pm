package Treex::Block::A2A::FlowNetwork;
use Moose;
use Treex::Core::Common;
use Graph;
use Graph::Undirected;

extends 'Treex::Core::Block';

has 'to_language' => ( is => 'rw', isa => 'Str', default => '' );
has 'to_selector' => ( is => 'rw', isa => 'Str', default => '' );

sub process_bundle {
    my ( $self, $bundle ) = @_;
    my $source_tree = $bundle->get_tree( $self->language, 'a', $self->selector);
    my $target_tree = $bundle->get_tree( $self->to_language, 'a', $self->to_selector);
    my $network = Graph::Undirected->new;
    foreach my $node ($source_tree->get_descendants) {
        my $ord = $node->ord;
        my @scores = split /\s/, $node->wild()->{'mst_score'};
        foreach my $to_ord (0 .. $#scores) {
            $network->add_weighted_edge("sn$ord", "se$ord", $score[$to_ord]);
            $network->add_weighted_edge("se$ord", "sn$to_ord", $score[$to_ord]);
            $network->add_weighted_edge("s", "se$ord", 2*$score[$to_ord]);
        }
        my ($alinodes, $alitypes) = $node->get_aligned_nodes();
        foreach my $n (0 .. $#$alinodes) {
            my $target_ord = $$alinodes[$n]->ord;
            my $weight = $$alitypes[$n] =~ /left/ ? 0.5 : 0;
            $weight += $$alitypes[$n] =~ /right/ ? 0.5 : 0;
            $network->add_weighted_edge("sn$ord", "tn$target_ord", $weight);
        }
    }
    foreach my $node ($target_tree->get_descendants) {
        my $ord = $node->ord;
        my @scores = split /\s/, $node->wild()->{'mst_score'};
        foreach my $to_ord (0 .. $#scores) {
            $network->add_weighted_edge("tn$ord", "te$ord", $score[$to_ord]);
            $network->add_weighted_edge("te$ord", "tn$to_ord", $score[$to_ord]);
            $network->add_weighted_edge("t", "te$ord", 2*$score[$to_ord]);
        }
    }
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


