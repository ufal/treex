package Treex::Block::A2W::CS::RemoveRepeatedTokens;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;

    my $original_sentence = $zone->sentence;
    my @tokens = split /\b/, $original_sentence;

    my $reduced_sentence = '';
    my $prev_nonempty;

    foreach my $i ( 0 .. $#tokens ) {

        if ($i == 0
            or $tokens[$i] =~ /^\s+$/
            or lc( $tokens[$i] ) ne $prev_nonempty
            or $prev_nonempty =~ /^xxx.+xxx$/i #xxxURLxxx created by W2A::HideIT
            )
        {
            $reduced_sentence .= $tokens[$i];
        }

        if ( $tokens[$i] !~ /^\s+$/ ) {
            $prev_nonempty = lc( $tokens[$i] );
        }
    }

    $reduced_sentence =~ s/\s+/ /g;         # this should be rewritten, so that space is correctly preserved in all cases!!!
    $reduced_sentence =~ s/ ([.,])$/$1/g;

    if ( $original_sentence ne $reduced_sentence ) {
        $zone->set_sentence($reduced_sentence);
    }
    return;
}

1;

=over

=item Treex::Block::A2W::CS::RemoveRepeatedTokens

Remove one of two identical neighbouring tokens,
e.g. 'se se' because of haplology ('Snazil se se tomu vyhnout')
of because of non-one-to-one t-nodes ('no one' -> 'nikdo nikdo').

=back

=cut

# Copyright 2010 Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
