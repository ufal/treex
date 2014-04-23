package Treex::Block::Eval::BiEdgeScore;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# source language
has '+language' => ( required => 1 );
has '+selector' => ( required => 1 );

has _biedge_count => (is => 'rw', isa => 'Int', default => 0 );
has _total_count => (is => 'rw', isa => 'Int', default => 0 );

my $total_count = 0;
my $biedge_count = 0;

sub process_atree {
	my ($self, $root) = @_;
    my @nodes = $root->get_descendants( { ordered => 1 } );
    my %alignment;
	foreach my $node (@nodes) {
        my ($alinodes, $alitypes) = $node->get_aligned_nodes;
        foreach my $i (0 .. $#$alinodes) {
            if ($$alitypes[$i] =~ /int/) {
                $alignment{$node} = $$alinodes[$i];
                last;
            }
        }
    }
    foreach my $node (@nodes) {
        if (defined $alignment{$node}) {
            my $counterpart = $alignment{$node};
            $total_count++;
            my $parent = $node->get_parent;
            if (defined $alignment{$parent} && $alignment{$parent} == $counterpart->get_parent) {
                $biedge_count++;
            }
        }
    }
}

sub process_end {
    my ($self) = @_;
    my $score = $biedge_count / $total_count;
    print "BiEdge score: $score\n";
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Eval::BiEdgeScore

=head1 DESCRIPTION

The BiEdgeScore shows tree similarity between two aligned treebanks. 

=head1 AUTHOR

David Marecek <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
