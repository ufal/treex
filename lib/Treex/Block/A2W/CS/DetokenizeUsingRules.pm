package Treex::Block::A2W::CS::DetokenizeUsingRules;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    my $sentence = $zone->sentence;

    $sentence =~ s/ +/ /g;
    $sentence =~ s/ ([,.?:;!])/$1/g;
    $sentence =~ s/ “/“/g;
    $sentence =~ s/„ /„/g;

    $sentence =~ s/([-"„;:,]),/$1/g;          # !!! tohle by chtelo udelat poradne a umazavat uz a-uzly
    $sentence =~ s/ ?([.,!?]) ?([“"])/$1$2/g;    # mazani mezer kolem interpunkce

    $sentence =~ s/ -- / - /g;

    $sentence =~ s/ rocích/ letech/g;
    $sentence =~ s/(v|V) roku/$1 roce/g;
    $sentence =~ s/ US / USA /g;

    # zavorky
    $sentence =~ s/,?\(,? ?/\(/g;
    $sentence =~ s/ ?,? ?\)/\)/g;

    # (The whole sentence is in parenthesis).
    # (The whole sentence is in parenthesis.)
    if ( $sentence =~ /^\(/ ) {
        $sentence =~ s/\)\./.)/;
    }

    $sentence =~ s/&#241;/ň/g;    # "ñ" is encoded as &#241; in translation dict

    $sentence =~ s/^ +//;
    $sentence =~ s/ +$//;

    $zone->set_sentence($sentence);
    return;
}

1;

=over

=item Treex::Block::A2W::CS::DetokenizeUsingRules

The sentence stored in $zone->sentence is detokenized:
spacing around punctuation marks is handled
and few hacks applied :-).

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
