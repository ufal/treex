package Treex::Block::A2W::CS::RemoveRepeatedTokens;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'cs' );




sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $original_sentence = $bundle->get_attr( 'czech_target_sentence' );
    my @tokens = split /\b/, $original_sentence;

    my $reduced_sentence;
    my $prev_nonemtpy;

    foreach my $i (0..$#tokens) {

        if ($i == 0
                or $tokens[$i] =~ /^\s+$/
                    or lc($tokens[$i]) ne $prev_nonemtpy) {
            $reduced_sentence .= $tokens[$i];
        }

        if ($tokens[$i] !~ /^\s+$/) {
            $prev_nonemtpy = lc($tokens[$i]);
        }
    }

    $reduced_sentence =~ s/\s+/ /g;  # this should be rewritten, so that space is correctly preserved in all cases!!!
    $reduced_sentence =~ s/ ([.,])$/$1/g;

    if ($original_sentence ne $reduced_sentence) {
        $bundle->set_attr('czech_target_sentence', $reduced_sentence);
    }
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
