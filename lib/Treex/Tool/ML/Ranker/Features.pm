package Treex::Tool::ML::Ranker::Features;

use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;

#requires '_unary_features';
#requires '_binary_features';

has 'node1_label' => (is => 'ro', isa => 'Str', default => 'n1');
has 'node2_label' => (is => 'ro', isa => 'Str', default => 'n2');
has '_prefix_unary' => (is => 'ro', isa => 'Bool', builder => '_build_prefix_unary', init_arg => undef);

sub _build_prefix_unary {
    return 1;
}

sub cat {
    my ($self, $feats, $name) = @_;

    my $val1 = $feats->{$self->node1_label . "_" . $name} // "";
    my $val2 = $feats->{$self->node2_label . "_" . $name} // "";
    return $val1 . "_" . $val2;
}

sub eq {
    my ($self, $feats, $name) = @_;

    my $val1 = $feats->{$self->node1_label . "_" . $name} // "";
    my $val2 = $feats->{$self->node2_label . "_" . $name} // "";
    return $val1 eq $val2 ? 1 : 0;
}

sub feat_hash_to_nslist {
    my ($hash) = @_;
    # unfold possible array values of the hash
    # allow defined values only
    my @unfolded_defined_list = grep {defined $_->[1]} map {
        my $key = $_;
        if (ref($hash->{$key}) eq "ARRAY") {
            map {[$key, $_]} @{$hash->{$key}};
        }
        else {
            [$key, $hash->{$key}];
        }
    } keys %$hash;
    my @nslist = _list_to_nslist(@unfolded_defined_list);
    return \@nslist;
}

sub _list_to_nslist {
    my (@list) = @_;
    
    my %ns_feats = ();
    foreach my $feat (@list) {
        my ($key, $value) = @$feat;
        if ($key =~ /^(.*)\^(.*)$/) {
            my $old = $ns_feats{$1} // [];
            push @$old, [$2, $value];
            $ns_feats{$1} = $old;
        }
        else {
            my $old = $ns_feats{default} // [];
            push @$old, [$key, $value];
            $ns_feats{default} = $old;
        }
    }
    my @ns_list = ();
    # default namespace is always the last, all the other are ordered alphabetically
    foreach my $ns (sort {$a eq "default" ? 1 : ($b eq "default" ? -1 : ($a cmp $b))} keys %ns_feats) {
        # indicator of the new namespace (key starting with "|", undef value)
        push @ns_list, ["|$ns", undef];
        # all the features from this namespace follow - sorted by their name
        push @ns_list, (sort {(join "", @$a) cmp (join "", @$b)} @{$ns_feats{$ns}});
    }
    return @ns_list;
}

sub _unary_features {
    my ($self, $node, $type) = @_;
    my $feats = inner();
    $feats = $self->prefix_with_ns($feats, $type);
    $feats = $self->prefix_with_type($feats, $type);
    return $feats;
}

sub prefix_with_type {
    my ($self, $feats, $type) = @_;
    return $feats if (!$self->_prefix_unary);
    my %new_feats = map {my $new_feat = $_; $new_feat =~ s/^((?:[^\^]+\^)?)/$1$type\_/g; $new_feat => $feats->{$_}} keys %$feats;
    return \%new_feats;
}

sub prefix_with_ns {
    my ($self, $feats, $type) = @_;
    return $feats;
}

sub _binary_features {
    log_warn 'Treex::Tool::ML::Ranker::Features is an abstract class. The _binary_features method must be implemented in a subclass.';
}

sub merge_cand_feats {
    my ($cand_feats_h, $merge_cands) = @_;
    my ($new_classes, $cands_to_new_classes) = @$merge_cands;
    my %merged_feats = map { $_ => {"c^__".$_."__" => 1} } @$new_classes;
    for (my $i = 0; $i < @$cand_feats_h; $i++) {
        merge_feats($merged_feats{$cands_to_new_classes->[$i]}, $cand_feats_h->[$i]);
    }
    my @merged_feat_arr = map {$merged_feats{$_}} @$new_classes;
    return @merged_feat_arr;
}

sub merge_feats {
    my ($f1, $f2) = @_;
    foreach my $k2 (keys %$f2) {
        my $v1 = $f1->{$k2};
        my @v1_arr = ();
        if (defined $v1) {
            @v1_arr = ( $v1 );
            if (ref($v1) eq "ARRAY") {
                @v1_arr = @$v1;
            }
        }
        my $v2 = $f2->{$k2};
        my @v2_arr = ();
        if (defined $v2) {
            @v2_arr = ( $v2 );
            if (ref($v2) eq "ARRAY") {
                @v2_arr = @$v2;
            }
        }
        push @v1_arr, @v2_arr;

        $f1->{$k2} = \@v1_arr;
    }
    return $f1;
}


sub create_instances {
    my ($self, $node1, $spec_classes, $cands, $merge_cands) = @_;
    
    my $node1_unary_h = $self->_unary_features( $node1, $self->node1_label );
    my $node1_unary_l = feat_hash_to_nslist($node1_unary_h);

    my @spec_class_feats_h = ();
    # TODO: ord should be incremented only for the real candidates, however current models are trained with ord=1 for __SELF__
    my $ord = 1;
    foreach my $class (@$spec_classes) {
        my $cand_h = $self->prefix_with_ns({$class => 1}, $self->node2_label);
        push @spec_class_feats_h, $cand_h;
        $ord++;
    }
    my @cands_feats_h = ();
    foreach my $cand (@$cands) {
        next if ($cand == $node1);

        my $cand_unary_h = $self->_unary_features( $cand, $self->node2_label );
        # TODO for convenience we merge the two hashes into a single one => should be passed separately
        my $both_unary_h = {%$cand_unary_h, %$node1_unary_h};
        my $cand_binary_h = $self->_binary_features( $both_unary_h, $node1, $cand, $ord );
        my $cand_h = { %$cand_unary_h, %$cand_binary_h};
        push @cands_feats_h, $cand_h;
        $ord++;
    }

    if (defined $merge_cands) {
        @cands_feats_h = merge_cand_feats(\@cands_feats_h, $merge_cands);
    }
    my @all_cand_feats_h = ( @spec_class_feats_h, @cands_feats_h );

    my @all_cand_feats = ();
    foreach my $cand_h (@all_cand_feats_h) {
        my $cand_l = feat_hash_to_nslist($cand_h);
        push @all_cand_feats, $cand_l;
    }

    my $instance = [\@all_cand_feats, $node1_unary_l];
    
    return $instance;
}

1;
