package Treex::Tool::Coreference::CorefFeatures;
use Moose::Role;

has 'feature_names' => (
    is          => 'ro',
    required    => 1,
    isa         => 'ArrayRef[Str]',
    lazy        => 1,
    builder     => '_build_feature_names',
);

requires '_build_feature_names';

requires '_unary_features';
requires '_binary_features';

# TODO following is here just for the time being. it is not abstract enough
requires 'init_doc_features';

sub anaph_feature_names {
    my ($self) = @_;
    my @names = grep {$_ =~ /anaph/} @{$self->feature_names};
    return \@names;
}
sub nonanaph_feature_names {
    my ($self) = @_;
    my @names = grep {$_ !~ /anaph/} @{$self->feature_names};
    return \@names;
}

sub extract_anaph_features {
    my ($self, $anaph) = @_;
    return $self->_unary_features( $anaph, 'anaph' );
}

sub extract_nonanaph_features {
    my ($self, $anaph_features, $anaph, $cand, $candord) = @_;
    
    my $cand_features = $self->_unary_features( $cand, 'cand' );
    my $unary_features = {%$anaph_features, %$cand_features};
    my $binary_features = $self->_binary_features( 
        $unary_features, $anaph, $cand, $candord );

    return {%$cand_features, %$binary_features};
}

sub create_joint_instances {
    my ($self, $anaph, $ante_cands, $ords) = @_;

    my $instances = 
        $self->create_instances( $anaph, $ante_cands, $ords );
    my $joint_instances = $instances->{'cands'};

    foreach my $cand_id (keys %{$joint_instances}) {
        $joint_instances->{$cand_id} = {
            %{$joint_instances->{$cand_id}},
            %{$instances->{'anaph'}},
        };
    }
    return $joint_instances;
}

sub create_instances {
    my ( $self, $anaph, $ante_cands, $ords ) = @_;

    if (!defined $ords) {
        my @antes_only_cands = grep { $_ != $anaph } @$ante_cands;
        $ords = [ 0 .. @antes_only_cands-1 ];
    }

    my $anaph_instance = $self->extract_anaph_features( $anaph );

    my $cand_instances;
    #print STDERR "ANTE_CANDS: " . @$ante_cands . "\n";
    foreach my $cand (@$ante_cands) {
    
        my $features = $anaph_instance;
        if ($cand == $anaph) {
            $features = {};
        }
        else {
            my $ord = shift @$ords;
            $features = $self->extract_nonanaph_features( 
                $features, $anaph, $cand, $ord );
        }

        $cand_instances->{ $cand->id } = $features;
    }

    my $instances = {
        anaph => $anaph_instance,
        cands => $cand_instances,
    };
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
