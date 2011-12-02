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

has 'miss_sents_to_break' => (
    is  => 'ro',
    isa => 'Int',
    default => 3,
    required => 1,
);

has 'languages' => (
    is  => 'ro',
    isa => 'ArrayRef[Treex::Type::LangCode]',
    default => sub{ ['cs', 'en'] },
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

has '_feats' => (
    is => 'ro',
    isa => 'ArrayRef[Str]',
    required => 1,
    lazy => 1,
    builder => '_build_feats',
);

sub BUILD {
    my ($self) = @_;

    $self->_feats;
}


sub _build_feats {
    my ($self) = @_;

    my @feat_names = ();

    # langs should come from a parameter
    my $langs = $self->languages;
    my @types = qw/estim true/;

    foreach my $lang (@$langs) {
        foreach my $type (@types) {
            my $feat_name = $type . '_interlinks/' . $lang . '_' . $self->selector;
            push @feat_names, $feat_name;
        }
    }

    return \@feat_names;
}

sub _find_breaks {
    my ($self) = @_;
    return log_fatal "method _find_breaks must be overriden in " . ref($self);
}

sub _split_scores_on_sure_breaks {
    my ($self, $scores, $sure_breaks) = @_;

    my @segs = ();

    my @sorted_idxs = sort {$a <=> $b} @$sure_breaks;
    my $start_idx = (shift @sorted_idxs) || 0;

    foreach my $end_idx (@sorted_idxs) {
        my @seg = @{$scores}[ $start_idx .. ($end_idx - 1) ];
        push @segs, \@seg;
        $start_idx = $end_idx;
    }
    my @last_seg = @{$scores}[ $start_idx .. (@$scores - 1) ];
    if (@last_seg > 0) {
        push @segs, \@last_seg;
    }
    else {
        return log_fatal "last seg should be always > 0" . ref($self);
    }

    return @segs;
}

sub _get_already_set_breaks {
    my ($self, @bundles) = @_;

    my @breaks = ();

    my $i = 0;
    my $prev_doc = undef;
    foreach my $bundle (@bundles) {
        
        ############## break in case of a document change ##############
        
        # find out the name of the full document
        my $curr_doc = $bundle->attr('czeng/origfile');
        $curr_doc =~ s/\.seg-\d+$// if defined $curr_doc;

        my $doc_break = 0;

        # make a break
        if (defined $curr_doc && (!defined $prev_doc || ($curr_doc ne $prev_doc))) {
            $doc_break = 1;
        }
        $prev_doc = $curr_doc;

        ############# break in case of a too large gap #################

        my $total_missing_sents = $bundle->attr('czeng/missing_sents_before') || 0;
        # in a dry run, the number of missing bundles coming from a soft filtering is not 
        # included in the attribute above, it is stored separately in a wild attribute
        if ($self->dry_run) {
            $total_missing_sents += $bundle->wild->{'missing_sents_before'} || 0;
        }

        my $miss_break = 0;

        if ($total_missing_sents >= $self->miss_sents_to_break) {
            $miss_break = 1;
        }
            
        ############ make a break #########################

        if ($doc_break || $miss_break) {
            push @breaks, $i;
        }
        
        # this should't happen
        if ($doc_break && $miss_break) {
            log_warn "Document break cannot appear at the same place as a break due too many missing sentences";
        }

        $i++;
    }
   
    # the beginning of document is always a break
    if (@breaks == 0) {
        push @breaks, 0;
    }

    return @breaks;
}

sub _count_scores {
    my ($self, @bundles) = @_;

    my @scores = ();

    foreach my $bundle (@bundles) {
        my @values = map { $bundle->wild->{$_} || 0 } @{$self->_feats};

        #print STDERR join ", ", @values;
        #print STDERR "\n";

        my $score = 0;
        $score += $_ foreach (@values);
        push @scores, $score;
    }
    return @scores;
}

sub process_document {
    my ($self, $doc) = @_;
    
    # remove_bundles doesn't work, bundles to remove are just labeled with the 'to_remove' attribute
    my @bundles = grep {!$_->wild->{to_delete}} $doc->get_bundles;

    my @sure_breaks = $self->_get_already_set_breaks( @bundles );
    
    #print STDERR join ", ", @sure_breaks;
    #print STDERR "\n";
    #print STDERR "COUTN: " . (scalar (keys %$old_breaks)) . "\n";

    #print STDERR join ", ", @{$self->_feats};
    #print STDERR "\n";

    my @scores = $self->_count_scores( @bundles );
    #print STDERR "SCORES: " . join ", ", @scores;
    #print STDERR "\n";

    #print STDERR "SCORES: " . (join ", ", @scores) . "\n";

    my @score_segms = $self->_split_scores_on_sure_breaks( \@scores, \@sure_breaks );
    
    for (my $i = 0; $i < @score_segms; $i++) {
        
        my @break_idx_segm = $self->_find_breaks( $score_segms[$i] );
        #my @links = qw/0 1 3 5 3 4 5 6 7 8 9 4 3 4 3 2 2 1/;
        #my @break_idx_segm = $self->_find_breaks( \@links );
        
        #print STDERR "BREAKS: " . (join ", ", @break_idx_segm) . "\n";
        

        my @break_bundles = map {
            $bundles[$sure_breaks[$i] + $_]
        } @break_idx_segm;
        foreach my $bundle (@break_bundles) {
            $bundle->wild->{$self->selector . 'segm_break'} = 1;
        }

    }

    my @break_idxs = grep {
        $bundles[$_]->wild->{$self->selector . 'segm_break'}
    } (0 .. @bundles-1);
    
    #print STDERR join ", ", @break_idx_list;
    #print STDERR "\n";
    
    if (!$self->dry_run) {
        foreach my $lang (@{$self->languages}) {

            # skip non-existing zones
            next if (!defined $bundles[0]->get_zone($lang, $self->selector));
            
            my $interlinks = Treex::Tool::Coreference::InterSentLinks->new({ 
                doc => $doc, language => $lang, selector => $self->selector
            });
            $interlinks->remove_selected( \@break_idxs );
        }
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
