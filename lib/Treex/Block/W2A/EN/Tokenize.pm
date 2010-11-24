package Treex::Block::W2A::EN::Tokenize;

our $VERSION = '0.1';

use Moose;
use MooseX::FollowPBP;

extends Treex::Block::W2A::Tokenize;

use Report;
use utf8;

override "tokenize_sentence" => sub {

    my $sentence = shift;
    $sentence = super($sentence);
    $sentence =~ s/^(.*)$/ $1 /;

    # it's, I'm, we'd, we're, you'll, I've, Peter's
    $sentence =~ s/([\'’])(s|m|d|ll|re|ve|S|M|D|LL|RE|VE)\s/ $1$2 /g;
    
    # don't
    $sentence =~ s/(n[\'’]t\s)/ $1 /g;
    $sentence =~ s/(N[\'’]T\s)/ $1 /g;

    # cannot, wanna ...
    $sentence =~ s/ ([Cc])annot / $1an not /g;
    $sentence =~ s/ ([Dd])'ye / $1' ye /g;
    $sentence =~ s/ ([Gg])imme / $1im me /g;
    $sentence =~ s/ ([Gg])onna / $1on na /g;
    $sentence =~ s/ ([Gg])otta / $1ot ta /g;
    $sentence =~ s/ ([Ll])emme / $1em me /g;
    $sentence =~ s/ ([Mm])ore'n / $1ore 'n /g;
    $sentence =~ s/ '([Tt])is / '$1 is /g;
    $sentence =~ s/ '([Tt])was / '$1 was /g;
    $sentence =~ s/ ([Ww])anna / $1an na /g;

    # clean out extra spaces
    $sentence =~ s/\s+/ /g;
    $sentence =~ s/^\s*//g;
    $sentence =~ s/\s*$//g;

    return $sentence;
}

1;

__END__

=over

=item Treex::Block::W2A::EN::Tokenize

Each sentence is split into a sequence of tokens using a series of regepxs.
Analytical tree is build and attributes C<no_space_after> are filled.

=back

=cut

# Copyright 2010 David Marecek
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
