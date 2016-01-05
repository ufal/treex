package Treex::Block::Print::TagChanges;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has 'selector' => (
    is => 'ro',
    default => 'ref',
);

has 'style' => (
    is => 'ro',
    isa => 'Str',
    default => 'pdt',
);

has '+language' => ( required => 1 );

my %count; 
my %total; 

sub process_anode {
    my ($self, $anode) = @_;
    my ($nodes, $types) = $anode->get_directed_aligned_nodes;
    my $anode2 = $nodes->[0];
    if ($anode2) {
        return if $anode->lemma ne $anode2->lemma;
        my $tag = $anode->tag;
        my $tag2 = $anode2->tag;
        if ($self->style eq 'mst') {
            if ($tag =~ /^(.)(.)..(.)...../) {
                $tag = $3 eq '-' ? $1.$2 : $1.$3;
            }
            if ($tag2 =~ /^(.)(.)..(.)...../) {
                $tag2 = $3 eq '-' ? $1.$2 : $1.$3;
            }
        }
        $count{$tag}{$tag2}++;
        $total{$tag}++;
    }
}

sub process_end {
     my $self = shift;
     foreach my $tag (keys %count) {
        foreach my $tag2 (keys %{$count{$tag}}) {
            if ($tag ne $tag2) {
#            log_warn("p");
                my $ratio = $count{$tag}{$tag2} / $total{$tag};
                print { $self->_file_handle() } ("$tag\t$tag2\t$ratio\n");
            }
        }
    }
}

1;

=head1 NAME

Treex::Block::Print::TagChanges

=head1 DESCRIPTION

Print a statistics about tag differences between two aligned a-trees in the same language

Lists all encountered C<conll/cpos,pos,feat> and C<tag>s with frequencies.

=cut

# Copyright 2011 David Marecek <marecek@ufal.mff.cuni.cz>
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
