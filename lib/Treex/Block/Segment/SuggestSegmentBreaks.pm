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

has 'regul_param' => (
    is  => 'ro',
    isa => 'Num',
    default => 0.5,
    required => 1,
);

sub _divide_to_equal_parts {
    my ($self, $scores, $block_breaks) = @_;

    my @break_idx_list = (0);
    my $without_break = 1;
    
    # to reduce a rate of segmentation, documents are processed in the reversed order
    # at least at the beginning of a document, the number of interlinks is a non-decreasing sequence of integers
    for (my $i = 1; $i < scalar @$scores; $i++) {
        if (defined $block_breaks->{$i}) {
            push @break_idx_list, $i;
            $without_break = 1;
            next;
        }
        if ($without_break % $self->max_size == 0) {
            push @break_idx_list, $i;
        }
        $without_break++;
    }

    return @break_idx_list;
}

sub _get_break_idx_list {
    my ($self, $scores, $block_breaks) = @_;

    my @break_idx_list = (0);

    my $sum = 0;
    my $min_avg_diff = undef;
    
    my $without_break = 1;
    my $min_idx = undef;

    # to reduce a rate of segmentation, documents are processed in the reversed order
    # at least at the beginning of a document, the number of interlinks is a non-decreasing sequence of integers
    for (my $i = 1; $i < scalar @$scores; $i++) {

        #print STDERR "$i:$without_break\n";
        
        if (defined $block_breaks->{$i}) {
            push @break_idx_list, $i;
            $without_break = 1;
            $min_idx = $i + 1;
            $min_avg_diff = undef;
            $sum = $scores->[$i];
            next;
        }

        # find and set a break if the size of the segment exceedes the maximum size
        if ($without_break > $self->max_size) {
            push @break_idx_list, $min_idx;
            $sum = $scores->[$min_idx];
            $min_avg_diff = undef;
            $without_break = 1;
            for (my $j = $min_idx + 1; $j <= $i; $j++) {
                $without_break++;
                $sum += $scores->[$j];
                #my $curr_avg_diff = $scores->[$j] - ($sum / $without_break);
                my $curr_avg_diff = $scores->[$j] - ($sum / $without_break) + $self->regul_param * ($self->max_size - $without_break);
                #if (!defined $min_avg_diff || ($curr_avg_diff <= $min_avg_diff)) {
                if (($curr_avg_diff < 0) && (!defined $min_avg_diff || ($curr_avg_diff < $min_avg_diff))) {
                    $min_avg_diff = $curr_avg_diff;
                    $min_idx = $j;
                }
                if (!defined $min_avg_diff) {
                    $min_idx = $j;
                }
            }
        }
        else {
            $without_break++;
            $sum += $scores->[$i];
            #my $curr_avg_diff = $scores->[$i] - ($sum / $without_break);
            my $curr_avg_diff = $scores->[$i] - ($sum / $without_break) + $self->regul_param * ($self->max_size - $without_break);
            # cut a longer continuous segment in the last place with the minimum score
    #        if (!defined $min_avg_diff || ($curr_avg_diff <= $min_avg_diff)) {
            if (($curr_avg_diff < 0) && (!defined $min_avg_diff || ($curr_avg_diff < $min_avg_diff))) {
                $min_avg_diff = $curr_avg_diff;
                $min_idx = $i;
            }
            if (!defined $min_avg_diff) {
                $min_idx = $i;
            }
        }
        # always set a break if the segments are not interlinked
        #if ($self->_link_count($interlinks[$i]) == 0) {
        #    $min_idx = $i + 1;
        #    $without_break = 0;
        #    push @break_idx_list, $i;
        #}
    }
    # find and set a break if the size of the segment exceedes the maximum size
    if ($without_break > $self->max_size) {
        push @break_idx_list, $min_idx;
    }

    return @break_idx_list;
}

sub _get_already_set_breaks {
    my ($self, @bundles) = @_;

    my $breaks_hash = {};

    my $i = 0;
    my $prev_id = undef;
    foreach my $bundle (@bundles) {
        my $curr_id = $bundle->attr('czeng/blockid');
        if (defined $curr_id && (!defined $prev_id || ($curr_id ne $prev_id))) {
            $breaks_hash->{$i} = $curr_id;
        }
        $prev_id = $curr_id;
        $i++;
    }
    return $breaks_hash;
}

sub process_document {
    my ($self, $doc) = @_;

    my $type_prefix = 'estim';
    if ($self->true_values) {
        $type_prefix = 'true';
    }

    my $old_breaks = $self->_get_already_set_breaks( $doc->get_bundles );

    #print STDERR join ", ", sort {$a <=> $b} (keys %$old_breaks);
    #print STDERR "\n";
    #print STDERR "COUTN: " . (scalar (keys %$old_breaks)) . "\n";

    my @scores = map {$_->wild->{$type_prefix . '_interlinks'}} $doc->get_bundles;
    #print STDERR "SCORES: " . join ", ", @scores;
    #print STDERR "\n";
    
    my @break_idx_list;
    my @clever_idx_list = $self->_get_break_idx_list( \@scores, $old_breaks );
    my @equal_idx_list = $self->_divide_to_equal_parts( \@scores, $old_breaks );
        
    #@break_idx_list = @clever_idx_list;
    @break_idx_list = @equal_idx_list;
    
    #print STDERR join ", ", @break_idx_list;
    #print STDERR "\n";
    
    if (!$self->dry_run) {
        my $interlinks = Treex::Tool::Coreference::InterSentLinks->new({ 
            doc => $doc, language => $self->language, selector => $self->selector
        });
        $interlinks->remove_selected( \@break_idx_list );
    }

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
