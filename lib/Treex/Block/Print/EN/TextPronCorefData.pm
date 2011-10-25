package Treex::Block::Print::EN::TextPronCorefData;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Print::CorefData';

use Treex::Tool::Coreference::EN::PronCorefFeatures;
use Treex::Tool::Coreference::EN::TextPronAnteCandsGetter;
use Treex::Tool::Coreference::EN::PronAnaphFilter;

override '_build_feature_extractor' => sub {
    my ($self) = @_;
    my $fe = Treex::Tool::Coreference::EN::PronCorefFeatures->new();
    return $fe;
};

override '_build_ante_cands_selector' => sub {
    my ($self) = @_;
    my $acs = Treex::Tool::Coreference::EN::TextPronAnteCandsGetter->new({
        anaphor_as_candidate => 1,
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
