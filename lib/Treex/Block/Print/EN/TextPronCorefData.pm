package Treex::Block::Print::EN::TextPronCorefData;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Print::CorefData';

use Treex::Tool::Coreference::NounAnteCandsGetter;
use Treex::Tool::Coreference::EN::PronAnaphFilter;
use Treex::Tool::Coreference::EN::PronCorefFeatures;
use Treex::Tool::Coreference::CS::PronCorefFeatures;
use Treex::Tool::Coreference::Features::Container;
use Treex::Tool::Coreference::Features::Aligned;
# TODO this should be solved in another way
use Treex::Block::My::BitextCorefStats::EnPerspron;

has 'aligned_feats' => ( is => 'ro', isa => 'Bool', default => 1 );

override '_build_feature_extractor' => sub {
    my ($self) = @_;
    my @container = ();
 
    log_info "BEGIN";
    my $en_fe = Treex::Tool::Coreference::EN::PronCorefFeatures->new();
    push @container, $en_fe;
    log_info "EN::PronCorefFeatures";

    if ($self->aligned_feats) {
        log_info "Features::Aligned pred";
        my $aligned_fe = Treex::Tool::Coreference::Features::Aligned->new({
            feat_extractors => [ 
                Treex::Tool::Coreference::CS::PronCorefFeatures->new(),
            ],
            align_sieves => [ 'self', 'eparents', 'siblings', 
                \&Treex::Block::My::BitextCorefStats::EnPerspron::access_via_ancestor,
            ],
            align_filters => [
                \&Treex::Block::My::BitextCorefStats::EnPerspron::filter_self,
                \&Treex::Block::My::BitextCorefStats::EnPerspron::filter_eparents,
                \&Treex::Block::My::BitextCorefStats::EnPerspron::filter_siblings,
                \&Treex::Block::My::BitextCorefStats::EnPerspron::filter_ancestor,
            ],
            align_lang => 'cs',
            align_selector => 'src',
        });
        push @container, $aligned_fe;
        log_info "Features::Aligned po";
    }
    
    my $fe = Treex::Tool::Coreference::Features::Container->new({
        feat_extractors => \@container,
    });
        log_info "Features::Container";
    return $fe;
};

override '_build_ante_cands_selector' => sub {
    my ($self) = @_;
    my $acs = Treex::Tool::Coreference::NounAnteCandsGetter->new({
        prev_sents_num => 1,
        anaphor_as_candidate => $self->anaphor_as_candidate,
    });
    return $acs;
};

override '_build_anaph_cands_filter' => sub {
    my ($self) = @_;
    my $acf = Treex::Tool::Coreference::EN::PronAnaphFilter->new();
    return $acf;
};

1;

=over

=item Treex::Block::Print::EN::TextPronCorefData


=back

=cut

# Copyright 2008-2011 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
