package Treex::Block::Segment::SuggestSegmentBreaks;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

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

sub _get_interlinks {
    my ($self, $doc, $type) = @_;
    # type = gram | text | both

    my @interlinks = ();

    # id -> bool: processed nodes
    my %processed_node_ids = ();
    # ante_id -> [ anaph_id ]: links, which refers to a so far not visited antecedent
    my %non_visited_ante_ids = ();

    # process nodes in the reversed order
    foreach my $bundle (reverse $doc->get_bundles) {
        
        my %local_non_visited_ante_ids = %non_visited_ante_ids;
        
        foreach my $zone ($bundle->get_all_zones) {
            my $tree = $bundle->get_tree( $zone->language, 't', $zone->selector );

            foreach my $node (reverse $tree->get_descendants({ ordered => 1 })) {
                
                # remove links where $node is an antecedent
                foreach my $ante_id (keys %local_non_visited_ante_ids) {
                    if ($node->id eq $ante_id) {
                        delete $local_non_visited_ante_ids{$ante_id};
                    }
                }

                # get antes
                my @antes = ();
                if ($type eq 'gram') {
                    @antes = $node->get_coref_gram_nodes;
                }
                elsif ($type eq 'text') {
                    @antes = $node->get_coref_text_nodes;
                }
                else {
                    @antes = $node->get_coref_nodes;
                }
                #use Data::Dumper;
                #print STDERR Dumper(\@antes);

                # skip cataphoric links
                my @non_cataph = grep {!defined $processed_node_ids{$_->id}} @antes;
                # new links
                foreach my $ante (@non_cataph) {
                    push @{$local_non_visited_ante_ids{$ante->id}}, $node->id;
                }
                
                $processed_node_ids{ $node->id }++;
            }
        }
        # store the number of links from this tree to previous ones
        unshift @interlinks, \%local_non_visited_ante_ids;
        # retain the unresolved links
        %non_visited_ante_ids = %local_non_visited_ante_ids;
    }

    # the first element should be always empty => all antecedents have been found
    # shift @interlinks;
    return @interlinks;
}

sub _link_count {
    my ($self, $hash) = @_;
    # $hash : { ante_id => [ anaph_id ] }

    my $sum = 0;
    foreach my $ante_id (keys %$hash) {
        my $anaphs = $hash->{$ante_id};
        $sum += @$anaphs;
    }

    return $sum;
}

sub _get_break_idx_list {
    my ($self, @interlinks) = @_;

    my @break_idx_list = ();
    
    my $without_break = 0;
    my $min_idx = 0;

    for (my $i = 0; $i < scalar @interlinks; $i++) {
        
        # find and set a break if the size of the segment exceedes the maximum size
        if ($without_break >= $self->max_size) {
            push @break_idx_list, $min_idx;
            $without_break = $i - $min_idx;
            $min_idx++;
            for (my $j = $min_idx; $j < $i + 1; $j++) {
                if ($self->_link_count($interlinks[$j]) <= $self->_link_count($interlinks[$min_idx])) {
                    $min_idx = $j;
                }
            }
        }
        else {
            if ($self->_link_count($interlinks[$i]) <= $self->_link_count($interlinks[$min_idx])) {
                $min_idx = $i;
            }
            $without_break++;
        }

        # always set a break if the segments are not interlinked
        if ($self->_link_count($interlinks[$i]) == 0) {
            $min_idx = $i + 1;
            $without_break = 0;
            push @break_idx_list, $i;
        }
    }
    return @break_idx_list;
}

sub _remove_interlinks {
    my ($self, $doc, $interlinks, $break_idx_list) = @_;

    foreach my $i (@$break_idx_list) {

        my $local_links = $interlinks->[$i];
        
        # segments are interlinked
        foreach my $ante_id (keys %$local_links) {
            my $anaph_ids = $local_links->{$ante_id};

            foreach my $anaph_id (@$anaph_ids) {
                my $anaph = $doc->get_node_by_id( $anaph_id );
                my $ante  = $doc->get_node_by_id( $ante_id  );
                
                # remove the coref link from anaph to ante
                $anaph->remove_coref_nodes( $ante );
                # DEBUG
                if ($anaph->id eq 't-cmpr9413-002-p6s4a1') {
                    print STDERR "GALIBA\n";
                }
            }
        }
    }
}

sub process_document {
    my ( $self, $doc ) = @_;

# TODO sum cs and en links

    # TODO let the user select a type
    my @interlinks = $self->_get_interlinks( $doc, 'all');
    my @break_idx_list = $self->_get_break_idx_list( @interlinks );
    
    # DEBUG
    print STDERR Dumper(\@interlinks);
    print STDERR join ", ", @break_idx_list;
    print STDERR "\n";
    
    if (!$self->dry_run) {
        $self->_remove_interlinks( $doc, \@interlinks, \@break_idx_list );
    }

    my @bundles = $doc->get_bundles;
    foreach my $bundle (map {$bundles[$_]} @break_idx_list) {
        $bundle->wild->{'segm_break'} = 1;
    }
}

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
