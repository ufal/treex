package Treex::Tool::Lexicon::CS::Prefixes;

use utf8;
use strict;
use warnings;

my $PREFIXES =
    'anti|auto|bio|celo|euro|ex|hyper|intra|jedno|ko|kom|kon|maxi|mezi|mikro'
    . '|mini|mnoho|mono|multi|nad|nano|ne|neo|non|novo|od|para|po|pod|polo'
    . '|před|přes|pro|proti|proto|pseudo|re|sebe|sou|spolu|stejno|supra'
    . '|ultra|vice|více|vše|znovu';
my $PREFIX_RE = qr/$PREFIXES/;

sub divide {
    my ($string) = @_;
    return ( $string =~ /^($PREFIX_RE)(.+)/ );
}

1;

__END__

=head1 NAME

Treex::Tool::Lexicon::CS::Prefixes

=head1 SYNOPSIS

 use Treex::Tool::Lexicon::CS::Prefixes;
 my ($prefix, $rest) =  Treex::Tool::Lexicon::CS::Prefixes::divide('nadčlověk');
 # $prefix eq 'nad' and $rest eq 'člověk'

=cut

# Copyright 2010 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
