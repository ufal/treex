package Treex::Tool::ML::VowpalWabbit::Util;

use Moose;

use Treex::Core::Common;

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

    if (ref($x) eq 'HASH') {
        $x = [ map {$_ . '=' . $x->{$_}} keys %$x ];
    }

    my $x_str = join ' ', feats_perl_to_vw(@$x);

    # ":" and "|" is a special char in VW
    $x_str =~ s/:/__COL__/g;
    $x_str =~ s/\|/__PIPE__/g;
    return $x_str;
}

sub instance_to_multiline {
    my ($x, $y, $all_labels, $is_test, $y_str) = @_;

    my $instance_str = _x_to_str($x);

    $instance_str = "shared |s " . $instance_str . "\n";
    foreach my $label (@$all_labels) {
        my $loss = $label eq $y ? 0 : 1;
        $y_str = defined $y_str ? $y_str : "";
        if ($is_test) {
            $instance_str .= "$label $y_str|t $label\n";
        }
        else {
            $instance_str .= "$label:$loss $y_str|t $label\n";
        }
    }
    $instance_str .= "\n";
    return $instance_str;
}

sub feats_perl_to_vw {
    my (@feats) = @_;
    foreach (@feats) {
        utf8::encode($_);
    }
    return @feats;
}

sub feats_vw_to_perl {
    my (@feats) = @_;
    my @feats_no_ns = map {$_ =~ s/^[^^]*\^(.*)$/$1/; $_} @feats;
    foreach (@feats_no_ns) {
        utf8::decode($_);
    }
    return @feats_no_ns;
}

1;
