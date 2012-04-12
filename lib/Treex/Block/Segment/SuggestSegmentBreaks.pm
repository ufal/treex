package Treex::Block::Segment::SuggestSegmentBreaks;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use List::Util qw/sum/;

use Treex::Tool::CorefSegments::InterSentLinks;

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

my %FEAT_WEIGHTS = (
    estim_interlinks => 1,
    true_interlinks => 3,
    missing_sents_before => 1, 
);


sub _find_breaks {
    my ($self) = @_;
    return log_fatal "method '_find_breaks' must be overriden in " . ref($self);
}

sub name {
    my ($self) = @_;
    return log_fatal "method 'name' must be overriden in " . ref($self);
}

sub _split_scores_on_sure_breaks {
    my ($self, $scores, $sure_breaks) = @_;

    my @segs = ();
    my @sorted_idxs = sort {$a <=> $b} @$sure_breaks;

    if (@sorted_idxs == 0) {
        log_warn "No bundles in the current document. (" . ref($self) . ")";
        return @segs;
    }

    my $start_idx = shift @sorted_idxs;
    if ($start_idx > 0) {
        log_warn "Sure breaks must contain idx=0. (" . ref($self) . ")";
    }

    foreach my $end_idx (@sorted_idxs) {
        my @seg = @{$scores}[ $start_idx .. ($end_idx - 1) ];
        push @segs, \@seg;
        $start_idx = $end_idx;
    }
    my @last_seg = @{$scores}[ $start_idx .. (@$scores - 1) ];
    push @segs, \@last_seg;

    return @segs;
}

sub _get_already_set_breaks {
    my ($self, @bundles) = @_;

    if (@bundles == 0) {
        return ();
    }

    # beginning is always a break
    my @breaks = (0);

    # skip the gap before the first bundle
    my $first_bundle = shift @bundles;
    my $prev_doc = $first_bundle->attr('czeng/origfile');
    $prev_doc =~ s/\.seg-\d+$// if defined $prev_doc;

    my $i = 1;
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
        
        $i++;
    }

    # set the leading technical zero (break at the beginning of the doc) if it's missing
    #if (!grep {$_ == 0} @breaks) {
    #    push @breaks, 0;
    #}
   
    return @breaks;
}

sub _count_score {
    my ($self, $bundle) = @_;

    my $langs = $self->languages;

    #################### prepare feature values ##########################
    my %feats = ();
    my $estim_label = 'estim_interlinks';
    $feats{$estim_label} = sum(map {$bundle->wild->{$estim_label . "/" . $_ . "_" . $self->selector} || 0} @$langs);
    my $true_label = 'true_interlinks';
    $feats{$true_label} = sum(map {$bundle->wild->{$true_label . "/" . $_ . "_" . $self->selector} || 0} @$langs);
    my $total_missing_sents = $bundle->attr('czeng/missing_sents_before') || 0;
    # in a dry run, the number of missing bundles coming from a soft filtering is not 
    # included in the attribute above, it is stored separately in a wild attribute
    if ($self->dry_run) {
        $total_missing_sents += $bundle->wild->{'missing_sents_before'} || 0;
    }
    $feats{'missing_sents_before'} = $total_missing_sents;


    #print STDERR join ", ", @values;
    #print STDERR "\n";

    my $score = 0;
    $score += $feats{$_} * $FEAT_WEIGHTS{$_} foreach (keys %feats);
    return $score;
}

sub process_document {
    my ($self, $doc) = @_;
    
    #print STDERR "BUNDLE_COUNT: " . $doc->get_bundles . "\n";

    # remove_bundles doesn't work, bundles to remove are just labeled with the 'to_remove' attribute
    my @bundles = grep {!$_->wild->{to_delete}} $doc->get_bundles;
    #print STDERR "BUNDLE_COUNT: " . @bundles . "\n";

    # remove old segment breaks
    foreach my $bundle (grep {$_->wild->{$self->selector . $self->name  . 'segm_break'}} @bundles) {
        $bundle->wild->{$self->selector . $self->name  . 'segm_break'} = 0;
    }


    my @sure_breaks = $self->_get_already_set_breaks( @bundles );
    
    #print STDERR "SURE BREAKS: " . join ", ", @sure_breaks;
    #print STDERR "\n";
    #print STDERR "COUTN: " . (scalar (keys %$old_breaks)) . "\n";

    my @scores = map {$self->_count_score($_)} @bundles;

    #print STDERR "SCORES: " . (join ", ", @scores) . "\n";

    my @score_segms = $self->_split_scores_on_sure_breaks( \@scores, \@sure_breaks );

    #print STDERR "SCORES_SEGM_SIZES: " . (join ", ", map {scalar @{$_}} @score_segms) . "\n";
    
    for (my $i = 0; $i < @score_segms; $i++) {
        
        my @break_idx_segm = $self->_find_breaks( $score_segms[$i] );
        unshift @break_idx_segm, 0;
        #my @links = qw/0 1 3 5 3 4 5 6 7 8 9 4 3 4 3 2 2 1/;
        #my @break_idx_segm = $self->_find_breaks( \@links );
        
        #print STDERR "SEGMENT: " . (join ", ", @{$score_segms[$i]}) . "\n";
        #print STDERR "BREAKS: " . (join ", ", @break_idx_segm) . "\n";
        

        my @break_bundles = map {
            $bundles[$sure_breaks[$i] + $_]
        } @break_idx_segm;
        foreach my $bundle (@break_bundles) {
            $bundle->wild->{$self->selector . $self->name  . 'segm_break'} = 1;
        }

    }

    my @break_idxs = grep {
        $bundles[$_]->wild->{$self->selector . $self->name  . 'segm_break'}
    } (0 .. @bundles-1);
    
    #print STDERR "BREAKS-" . $self->selector . ": " . join ", ", @break_idxs;
    #print STDERR "\n";
    
    if (!$self->dry_run) {

        my %langs = map {
            map {$_->language => 1} (grep {($_->selector eq $self->selector) && ($_->has_ttree)} $_->get_all_zones)
        } @bundles;
        #print STDERR "LANGS: " . (join ", ", keys %langs) . "\n";
        foreach my $lang (keys %langs) {
        #foreach my $lang (@{$self->languages}) {

            # skip non-existing zones
            #next if (!defined $bundles[0]->get_zone($lang, $self->selector));
            my @trees = map {$_->get_tree($lang, 't', $self->selector)} @bundles;
            
            my $interlinks = Treex::Tool::CorefSegments::InterSentLinks->new({ 
                trees => \@trees
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
