package Treex::Tool::Coreference::CorefFeatures;

use Moose::Role;
use Moose::Util::TypeConstraints;

has 'feature_names' => (
    is          => 'ro',
    required    => 1,
    isa         => 'ArrayRef[Str]',
    lazy        => 1,
    builder     => '_build_feature_names',
);

has 'format' => (
    is          => 'ro',
    required    => 1,
    isa         => enum([qw/percep unsup/]),
    default     => 'percep',
);

requires '_build_feature_names';

requires '_unary_features';
requires '_binary_features';

my $b_true = '1';
my $b_false = '-1';

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

sub create_instances {
    my ($self, $anaph, $ante_cands, $ords) = @_;

    if ($self->format eq 'unsup') {
        return $self->_create_instances(
            $anaph, $ante_cands, $ords
        );
    }
    else {
        return $self->_create_joint_instances(
            $anaph, $ante_cands, $ords
        );
    }
}

sub _create_joint_instances {
    my ($self, $anaph, $ante_cands, $ords) = @_;

    my $instances = 
        $self->_create_instances( $anaph, $ante_cands, $ords );
    my $joint_instances = $instances->{'cands'};

    foreach my $cand_id (keys %{$joint_instances}) {
        $joint_instances->{$cand_id} = {
            %{$joint_instances->{$cand_id}},
            %{$instances->{'anaph'}},
        };
    }
    return $joint_instances;
}

sub _create_instances {
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

sub init_doc_features {
    my ($self, $doc, $lang, $sel) = @_;
    
    if ( !$doc->get_bundles() ) {
        return;
    }
    my @trees = map { $_->get_tree( 
        $lang, 't', $sel ) }
        $doc->get_bundles;

    $self->init_doc_features_from_trees( \@trees );
}

sub init_doc_features_from_trees {
    my ($self, $trees) = @_;
    
    $self->mark_doc_clause_nums( $trees );
    $self->mark_sentord_within_blocks( $trees );
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

sub mark_doc_clause_nums {
    my ($self, $trees) = @_;

    my $curr_clause_num = 0;
    foreach my $tree (@{$trees}) {
        my $clause_count = 0;
        
        foreach my $node ($tree->descendants ) {
            # TODO clause_number returns 0 for coap

            $node->wild->{aca_clausenum} = 
                $node->clause_number + $curr_clause_num;
            if ($node->clause_number > $clause_count) {
                $clause_count = $node->clause_number;
            }
        }
        $curr_clause_num += $clause_count;
    }
}

# quantization
# takes an array of numbers, which corresponds to the boundary values of
# clusters
sub _categorize {
    my ( $real, $bins_rf ) = @_;
    my $retval = "-inf";
    for (@$bins_rf) {
        $retval = $_ if $real >= $_;
    }
    return $retval;
}

sub _join_feats {
    my ($self, $f1, $f2) = @_;

# TODO adjustment to accord with Linh et al. (2009)
    if (!defined $f1) {
        $f1 = "";
    }
    if (!defined $f2) {
        $f2 = "";
    }

#    if (!defined $f1 || !defined $f2) {
#        return undef;
#    }
    return $f1 . '_' . $f2;
}

sub _agree_feats {
    my ($self, $f1, $f2) = @_;

# TODO adjustment to accord with Linh et al. (2009)
    if (!defined $f1 || !defined $f2) {
        if (!defined $f1 && !defined $f2) {
            return $b_true;
        }
        else {
            return $b_false;
        }
    }

#    if (!defined $f1 || !defined $f2) {
#        return $b_false;
#    }

    return ($f1 eq $f2) ? $b_true : $b_false;
}



# TODO doc
1;
