package Treex::Tool::Coreference::CorefFeatures;
use Moose::Role;

requires 'extract_features';

# TODO following is here just for the time being. it is not abstract enough
requires 'init_doc_features';

sub create_instances {
    my ( $self, $anaph, $ante_cands, $ords ) = @_;


    if (!defined $ords) {
        my @antes_only_cands = grep { $_ != $anaph } @$ante_cands;
        $ords = [ 0 .. @antes_only_cands-1 ];
    }

    my $instances;
    #print STDERR "ANTE_CANDS: " . @$ante_cands . "\n";
    foreach my $cand (@$ante_cands) {
        
        my $features;
        if ($cand == $anaph) {
            $features = $self->extract_features( $anaph );
        }
        else {
            my $ord = shift @$ords;
            $features = $self->extract_features( $anaph, $cand, $ord );
        }

        $instances->{ $cand->id } = $features;
    }
    return $instances;
}

sub mark_sentord_within_blocks {
    my ($self, $trees) = @_;

    my @non_def = grep {!defined $_->get_bundle->attr('czeng/blockid')} @$trees;

    my $is_czeng = (@non_def > 0) ? 0 : 1;

    my $i = 0;
    my $prev_blockid = undef;
    foreach my $tree (@$trees) {
        if ($is_czeng) {
            my $block_id = $tree->get_bundle->attr('czeng/blockid');
            if (defined $prev_blockid && ($block_id ne $prev_blockid)) {
                $i = 0;
            }
            $prev_blockid = $block_id;
        }
        $tree->wild->{czeng_sentord} = $i;
        $i++;
    }
}


# TODO doc
1;
