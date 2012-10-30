package Treex::Tool::ML::VowpalWabbit::Util;

use Moose;

use Treex::Core::Common;

sub instance_to_vw_str {
    my ($x, $y) = @_;

    if (ref($x) eq 'HASH') {
        $x = [ map {$_ . '=' . $x->{$_}} keys %$x ];
    }
    my $instance_str = join ' ', @$x;

    # : is a special char in VW
    $instance_str =~ s/:/=/g;

    if (defined $y) {
        $instance_str = "$y | $instance_str";
    }
    else {
        $instance_str = "| $instance_str";
    }
    
    return $instance_str;
}

1;
