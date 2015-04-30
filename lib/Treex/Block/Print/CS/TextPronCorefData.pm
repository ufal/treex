package Treex::Block::Print::CS::TextPronCorefData;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Print::CorefData';

use Treex::Tool::Coreference::NounAnteCandsGetter;
use Treex::Tool::Coreference::NodeFilter::PersPron;
use Treex::Tool::Coreference::EN::PronCorefFeatures;
use Treex::Tool::Coreference::CS::PronCorefFeatures;
use Treex::Tool::Coreference::Features::Container;
use Treex::Tool::Coreference::Features::Aligned;
use Treex::Tool::Coreference::Features::Coreference;

has 'aligned_feats' => ( is => 'ro', isa => 'Bool', default => 0 );

override '_build_feature_extractor' => sub {
    my ($self) = @_;
    my @container = ();
 
    my $cs_fe = Treex::Tool::Coreference::CS::PronCorefFeatures->new();
    push @container, $cs_fe;

    if ($self->aligned_feats) {
        my $aligned_fe = Treex::Tool::Coreference::Features::Aligned->new({
            feat_extractors => [ 
                Treex::Tool::Coreference::EN::PronCorefFeatures->new(),
                Treex::Tool::Coreference::Features::Coreference->new(),
            ],
            align_lang => 'en',
            align_types => ['supervised', '.*'],
        });
        push @container, $aligned_fe;
    }
    
    my $fe = Treex::Tool::Coreference::Features::Container->new({
        feat_extractors => \@container,
    });
    return $fe;
};

override '_build_ante_cands_selector' => sub {
    my ($self) = @_;
    my $acs = Treex::Tool::Coreference::NounAnteCandsGetter->new({
        prev_sents_num => 1,
        anaphor_as_candidate => $self->anaphor_as_candidate,
        cands_within_czeng_blocks => 1,
        max_size => 100,
    });
    return $acs;
};

override '_build_anaph_cands_filter' => sub {
    my ($self) = @_;
    #my $acf = Treex::Tool::Coreference::CS::PronAnaphFilter->new();
    my $acf = Treex::Tool::Coreference::NodeFilter::PersPron->new({
        args => {
                # excluding reflexive pronouns
                reflexive => -1,
                # both expressed and unexpressed
                expressed => 0,
            }
    });
    return $acf;
};

1;

=over

=item Treex::Block::Print::CS::TextPronCorefData


=back

=cut

# Copyright 2008-2011 Michal Novak

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
