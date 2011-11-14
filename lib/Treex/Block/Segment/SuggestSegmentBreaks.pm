package Treex::Block::Segment::SuggestSegmentBreaks;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Coreference::InterSentLinks;

has 'max_size' => (
    is  => 'ro',
    isa => 'Int',
    default => 13,
    required => 1,
);

# if TRUE, just labels the places where document can be splitted
# but does not remove any inter-segmental links
has 'dry_run' => (
    is  => 'ro',
    isa => 'Bool',
    default => 0,
    required => 1,
);

has 'true_values' => (
    is  => 'ro',
    isa => 'Bool',
    default => 0,
    required => 1,
);

sub _get_break_idx_list {
    my ($self, @scores) = @_;

    my @break_idx_list = (0);
    
    my $without_break = 0;
    my $min_idx = 0;

    for (my $i = 0; $i < scalar @scores; $i++) {
        
        # find and set a break if the size of the segment exceedes the maximum size
        if ($without_break >= $self->max_size) {
            push @break_idx_list, $min_idx;
            $without_break = $i - $min_idx;
            $min_idx++;
            for (my $j = $min_idx; $j < $i + 1; $j++) {
                if ($scores[$j] <= $scores[$min_idx]) {
                    $min_idx = $j;
                }
            }
        }
        else {
            # cut a longer continuous segment in the last place with the minimum score
            if ($scores[$i] <= $scores[$min_idx]) {
                $min_idx = $i;
            }
            $without_break++;
        }

        # always set a break if the segments are not interlinked
        #if ($self->_link_count($interlinks[$i]) == 0) {
        #    $min_idx = $i + 1;
        #    $without_break = 0;
        #    push @break_idx_list, $i;
        #}
    }
    return @break_idx_list;
}

sub process_document {
    my ($self, $doc) = @_;

    my $type_prefix = 'estim';
    if ($self->true_values) {
        $type_prefix = 'true';
    }

    my @scores = map {$_->wild->{$type_prefix . '_interlinks'}} $doc->get_bundles;
    my @break_idx_list = $self->_get_break_idx_list( @scores );
    
    if (!$self->dry_run) {
        my $interlinks = Treex::Tool::Coreference::InterSentLinks->new({ doc => $doc });
        $interlinks->remove_selected( \@break_idx_list );
    }

    #print STDERR Dumper(\@break_idx_list);
    #print STDERR Dumper($self->_scores);

    my @bundles = $doc->get_bundles;
    foreach my $bundle (map {$bundles[$_]} @break_idx_list) {
        $bundle->wild->{$type_prefix . '_segm_break'} = 1;
    }
}


#sub process_document {
#    my ( $self, $doc ) = @_;

# TODO sum cs and en links

    # TODO let the user select a type
    # my @interlinks = $self->_get_interlinks( $doc, 'all');
    # my @link_counts = $self->_link_counts( @interlinks );   
    # my @break_idx_list = $self->_get_break_idx_list( @link_counts );
    
#    my @break_idx_list = $self->_get_break_idx_list( @link_counts );
    
    # DEBUG
    #print STDERR Dumper(\@interlinks);
    #print STDERR join ", ", @break_idx_list;
    #print STDERR "\n";
    
#    if (!$self->dry_run) {
#        $self->_remove_interlinks( $doc, \@interlinks, \@break_idx_list );
#    }

#    my @bundles = $doc->get_bundles;
#    foreach my $bundle (map {$bundles[$_]} @break_idx_list) {
#        $bundle->wild->{'segm_break'} = 1;
#    }
#}

1;

=head1 NAME

Treex::Block::Segment::SuggestSegmentBreaks

=head1 DESCRIPTION

It suggests the places where to split the document into two segments.
The bundle which begins a new segment is labeled with an attribute
C<< wild->{'segm_break'} >>. These places are selected in the way that the 
number of disconnected coreference links is minimum.
All places which lie between segments that are not interlinked by
coreference relations are labeled as candidates. Intralinked segments
larger than C<max_size> bundles are divided in the place with the smallest
number links.

=head1 ATTRIBUTES

=over 4

=item max_size

the maximum allowed size of a segment

=item dry_run

if equal to 1, all inter-segmental links are retained, otherwise, removed

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
