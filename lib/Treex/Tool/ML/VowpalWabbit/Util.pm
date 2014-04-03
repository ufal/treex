package Treex::Tool::ML::VowpalWabbit::Util;

use Moose;
use Treex::Core::Common;
use List::Util;

sub format {
    my ($x, @args) = @_;
    if (ref($x) eq "HASH") {
        return _format_singleline($x, @args);
    }
    elsif (ref($x) eq "ARRAY") {
        return _format_multiline($x, @args);
    }
}

sub _format_multiline {
    my ($x, $y) = @_;

    my ($cands_x, $shared_x) = @$x;

    my $instance_str = "";

    if (defined $shared_x) {
        my $shared_str = _x_to_str($shared_x);
        $instance_str .= "shared |s " . $shared_str . "\n";
    }

    my $i = 0;
    foreach my $cand_x (@$cands_x) {
        my $cand_str = _x_to_str($cand_x);

        # train
        if (defined $y) {
            my $loss;
            if (ref($y) eq 'ARRAY') {
                $loss = any {$_ == $i} @$y ? 0 : 1;
            }
            else {
                $loss = $i == $y ? 0 : 1;
            }
            $instance_str .= sprintf "%d:%d |t %s\n", ($i+1), $loss, $cand_str;
        }
        # test
        else {
            $instance_str .= sprintf "%d |t %s\n", ($i+1), $y_str, $cand_str;
        }
    }
    $instance_str .= "\n";
    return $instance_str;
}

sub _format_singleline {
# TODO rewrite instance_to_vw_str
}

sub _x_to_str {
    my ($x) = @_;
    my @x_list = map {$_ . '=' . $x->{$_}} keys %$x;
    $x_str = join ' ', feats_perl_to_vw(@$x);
    return $x_str;
}


################### METHODS TO BE REMOVED ####################

sub instance_to_vw_str {
    my ($x, $y, $y_str) = @_;

    my $instance_str = _x_to_str($x);

    if (defined $y_str) {
        $instance_str = "$y $y_str| $instance_str";
    }
    elsif (defined $y) {
        $instance_str = "$y | $instance_str";
    }
    else {
        $instance_str = "| $instance_str";
    }
    
    return $instance_str;
}

sub _x_to_str {
    my ($x) = @_;
    my @x_list = map {$_ . '=' . $x->{$_}} keys %$x;
    $x_str = join ' ', feats_perl_to_vw(@$x);
    return $x_str;
}

sub _feats_to_str {
    my ($feats) = @_;

    my $feats_str = "";
    if (ref($feats_str) eq 'ARRAY') {
        my $val_hash = all {ref($_) eq 'HASH'} values %$feats_str;
        if ($val_hash) {
            my %str_hash = map {$_ => _x_to_str($feats_str->{$_})} keys %$feats_str;
            return \%str_hash;
        }
        else {
            return _x_to_str($feats_str);
        }
    }
}

sub instance_to_multiline {
    my ($x, $y, $all_labels, $is_test, $y_str) = @_;

    my $instance = _feats_to_str($x);
    my $instance_str = "";

    # shared
    my $shared_str;
    if (ref($instance) eq 'HASH') {
        if (defined $instance->{shared}) {
            $shared_str = $instance->{shared};
        }
    }
    else {
       $shared_str = $instance;
    }
    $instance_str = "shared |s " . $instance_str . "\n" if (defined $shared_str);

    if (!defined $all_labels && (ref($instance) eq 'HASH')) {
        $all_labels = [ keys %$instance ];
    }
    my %label_idx = map {$all_labels->[$_] => $_} 1 .. scalar @$all_labels;
    
    foreach my $label (@$all_labels) {
        $y_str = defined $y_str ? $y_str : "";
        
        my $feat_str = $label;
        if (ref($instance) eq 'HASH') {
            $feat_str = $instance->{$label};
        }

        if ($is_test) {
            $instance_str .= sprintf "%d %s|t %s\n", $label_idx{$label}, $y_str, $feat_str;
        }
        else {
            my $loss = $label eq $y ? 0 : 1;
            $instance_str .= sprintf "%d:%d %s|t %s\n", $label_idx{$label}, $loss, $y_str, $feat_str;
        }
    }
    $instance_str .= "\n";
    return $instance_str;
}

sub feats_perl_to_vw {
    my (@feats) = @_;
    foreach my $feat (@feats) {
        # ":" and "|" is a special char in VW
        $feat =~ s/:/__COL__/g;
        $feat =~ s/\|/__PIPE__/g;
        utf8::encode($feat);
    }
    return @feats;
}

sub feats_vw_to_perl {
    my (@feats) = @_;
    my @feats_no_ns = map {$_ =~ s/^[^^]*\^(.*)$/$1/; $_} @feats;
    foreach my $feat (@feats_no_ns) {
        utf8::decode($feat);
        $feat =~ s/__PIPE__/|/g;
        $feat =~ s/__COL__/:/g;
    }
    return @feats_no_ns;
}

sub split_to_classes {
    my ($array, $k) = @_;
    
    if (@$array % $k != 0) {
        log_fatal "Length of the array must be a multiple of the number of classes.";
    }

    my $feat_num = scalar @$array / $k;
    
    my $classed_array = {};
    for (my $i = 1; $i <= $k; $i++) {
        $classed_array->{$i} = [ @$array[$feat_num*($i-1) .. $feat_num*$i-1] ];
    }
    return $classed_array;
}

sub parse_csoaa_ldf {
}

1;
