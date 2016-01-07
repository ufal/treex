package Treex::Tool::Coreference::NodeFilter::Utils;

use Treex::Core::Common;
use Exporter 'import';
our @EXPORT_OK = qw(ternary_arg);

# processing ternary arguments for binary indicators
# arg = 0 : does not take the indicator into account
# arg = 1 : indicator must be true
# arg = -1 : indicator must be false
sub ternary_arg {
    my ($arg, $indicator) = @_;
    if ($arg > 0) {
        return $indicator;
    }
    elsif ($arg < 0) {
        return !$indicator;
    }
    else {
        return 1;
    }
}

1;
