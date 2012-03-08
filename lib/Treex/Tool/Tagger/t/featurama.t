#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

eval {
    require Featurama::Perc;
    1;
} or plan skip_all => 'Cannot load Featurama::Perc';

plan tests => 4;

use_ok 'Treex::Tool::Tagger::Featurama::Dummy';
SKIP:
{
    my %local_path;
    eval {
        require Treex::Core::Resource;
        foreach my $suffix (qw(f dict alpha)) {
            $local_path{$suffix} = Treex::Core::Resource::require_file_from_share("data/models/tagger/featurama/en/default.$suffix");
        }
        1;
    } or skip 'Cannot download models', 3;
    my $tagger = Treex::Tool::Tagger::Featurama::Dummy->new(
        alpha   => $local_path{alpha},
        feature => $local_path{f},
        dict    => $local_path{dict},
    );
    isa_ok( $tagger, 'Treex::Tool::Tagger::Featurama' );
    my ( $tags_rf, $lemmas_rf ) = $tagger->tag_sentence( [qw(How are you ?)] );
    cmp_ok( scalar @$tags_rf,   '==', 4, q{There's Correct number of tags} );
    cmp_ok( scalar @$lemmas_rf, '==', 4, q{There's Correct number of lemmas} );

}
