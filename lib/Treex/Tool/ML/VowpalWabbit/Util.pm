package Treex::Tool::ML::VowpalWabbit::Util;

use Moose;
use Treex::Core::Common;
use List::Util qw/min/;

my $SHARED_LABEL = "shared";
my $FEAT_VAL_DELIM = "=";
my $SELF_LABEL = "__SELF__";

#sub format {
#    my ($x, @args) = @_;
#    if (ref($x) eq "HASH") {
#        return _format_singleline($x, @args);
#    }
#    elsif (ref($x) eq "ARRAY") {
#        return _format_multiline($x, @args);
#    }
#}

sub format_multiline {
    my ($feats, $losses) = @_;

    my ($cands_feats, $shared_feats) = @$feats;

    my $instance_str = "";

    if (defined $shared_feats) {
        $instance_str .= format_singleline($shared_feats, $SHARED_LABEL);
    }

    my $comment = "";
    if (defined $losses) {
        my $min_loss = min @$losses;
        my @min_loss_idx = grep {$losses->[$_] == $min_loss} 0 .. $#$losses;
        $comment = join ",", (map {$_ + 1} @min_loss_idx);
       
        my ($self_cand_idx) = grep {
            my $feat = $cands_feats->[$_][0];
            if (ref($feat) eq 'ARRAY') {
                $feat->[0] eq $SELF_LABEL;
            }
            else {
                $feat eq $SELF_LABEL.$FEAT_VAL_DELIM."1";
            }
        } 0 .. $#$cands_feats;
        $comment .= '-' . ($self_cand_idx+1) if (defined $self_cand_idx);
    }
    
    my $i = 0;
    foreach my $cand_feats (@$cands_feats) {
        my $label = $i+1;
        if (defined $losses) {
            $label .= ":" . $losses->[$i];
        }
        $instance_str .= format_singleline($cand_feats, $label, $comment);
        $i++;
    }
    $instance_str .= "\n";
    return $instance_str;
}

sub format_singleline {
    my ($feats, $label, $comment) = @_;

    my @feat_str = map {
        ref($_) eq 'ARRAY' ?
            $_->[0] .$FEAT_VAL_DELIM. $_->[1] :
            $_;
    } @$feats;
    @feat_str = map {feat_perl_to_vw($_)} @feat_str;
    my $line = sprintf "%s %s|default %s\n",
        defined $label ? $label : "",
        defined $comment ? $comment : "",
        join " ", @feat_str;

    return $line;
}

#sub _x_to_str {
#    my ($x) = @_;
#    my @x_list = map {$_ . '=' . $x->{$_}} keys %$x;
#    $x_str = join ' ', feats_perl_to_vw(@$x);
#    return $x_str;
#}
#
#
#################### METHODS TO BE REMOVED ####################
#
#sub instance_to_vw_str {
#    my ($x, $y, $y_str) = @_;
#
#    my $instance_str = _x_to_str($x);
#
#    if (defined $y_str) {
#        $instance_str = "$y $y_str| $instance_str";
#    }
#    elsif (defined $y) {
#        $instance_str = "$y | $instance_str";
#    }
#    else {
#        $instance_str = "| $instance_str";
#    }
#    
#    return $instance_str;
#}
#
#sub _x_to_str {
#    my ($x) = @_;
#    my @x_list = map {$_ . '=' . $x->{$_}} keys %$x;
#    $x_str = join ' ', feats_perl_to_vw(@$x);
#    return $x_str;
#}
#
#sub _feats_to_str {
#    my ($feats) = @_;
#
#    my $feats_str = "";
#    if (ref($feats_str) eq 'ARRAY') {
#        my $val_hash = all {ref($_) eq 'HASH'} values %$feats_str;
#        if ($val_hash) {
#            my %str_hash = map {$_ => _x_to_str($feats_str->{$_})} keys %$feats_str;
#            return \%str_hash;
#        }
#        else {
#            return _x_to_str($feats_str);
#        }
#    }
#}
#
#sub instance_to_multiline {
#    my ($x, $y, $all_labels, $is_test, $y_str) = @_;
#
#    my $instance = _feats_to_str($x);
#    my $instance_str = "";
#
#    # shared
#    my $shared_str;
#    if (ref($instance) eq 'HASH') {
#        if (defined $instance->{shared}) {
#            $shared_str = $instance->{shared};
#        }
#    }
#    else {
#       $shared_str = $instance;
#    }
#    $instance_str = "shared |s " . $instance_str . "\n" if (defined $shared_str);
#
#    if (!defined $all_labels && (ref($instance) eq 'HASH')) {
#        $all_labels = [ keys %$instance ];
#    }
#    my %label_idx = map {$all_labels->[$_] => $_} 1 .. scalar @$all_labels;
#    
#    foreach my $label (@$all_labels) {
#        $y_str = defined $y_str ? $y_str : "";
#        
#        my $feat_str = $label;
#        if (ref($instance) eq 'HASH') {
#            $feat_str = $instance->{$label};
#        }
#
#        if ($is_test) {
#            $instance_str .= sprintf "%d %s|t %s\n", $label_idx{$label}, $y_str, $feat_str;
#        }
#        else {
#            my $loss = $label eq $y ? 0 : 1;
#            $instance_str .= sprintf "%d:%d %s|t %s\n", $label_idx{$label}, $loss, $y_str, $feat_str;
#        }
#    }
#    $instance_str .= "\n";
#    return $instance_str;
#}

sub feat_perl_to_vw {
    my ($feat) = @_;
    # ":" and "|" is a special char in VW
    $feat =~ s/:/__COL__/g;
    $feat =~ s/\|/__PIPE__/g;
    #utf8::encode($feat);
    return $feat;
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
