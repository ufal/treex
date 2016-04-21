package Treex::Block::T2A::CS::VocalizePrepos;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_atree {
    my ( $self, $a_root ) = @_;

    my @anodes = $a_root->get_descendants( { ordered => 1 } );

    # we consider bigrams
    foreach my $i ( 0 .. $#anodes - 1 ) {
        if ( $anodes[$i]->get_attr('morphcat/pos') =~ /^R/ ) {
            my $vocalized = vocalize( $anodes[$i]->lemma, $anodes[ $i + 1 ]->form );
            $anodes[$i]->set_form($vocalized);
        }
    }
    return;
}

sub vocalize {
    my $preposition = shift;
    my $follower    = lc(shift);

    return 'ku' if $preposition eq 'k' and $follower =~ /^(prospěch|příklad)/;

    return 'ke' if $preposition eq 'k' and $follower =~ /^(k|g|sp|s[cjklnv]|z[bcdhklmprřtv]|š[kptť]|mn|vš|vs|ct|dv|vč|lá|mř|vk|sta|vzn|stu|vzd|smí|stě|dnu|vzo|sti|sty|sro|dnů|sdr|sbl|sbí|čty|zná)/;

    return 've' if $preposition eq 'v' and $follower =~ /^(f|v|w|š[klpvrt]|s[bhjklnptvw]|cv|čt|kt|z[bdhklnpt]|ii|hř|dv|rw|tm|jm|ž[dďr]|hv|gi|gy|mz|sro|sml|tří|tva|srá|obž|zví|psa|smr|žlu|sca|zrů|sce|zvo|zme|mně$|mne$)/;

    return 'se' if $preposition eq 's' and $follower =~ /^(s|z|c[mtv]|kt|vz|vš|mn|š[eklptv]|že|čt|ps|vs|ži|ža|dž|bý|čle|jmě|ple|šam|lst|prs|dvě|dře|7|17$|1\d\d\D?)/;

    return 'ze' if $preposition eq 'z' and $follower =~ /^(s|z|dn|kt|kb|š[aiklptuv]|vs|vš|mz|tm|rt|lh|lv|ž[aiďl]|hry|vzd|tří|jmě|šes|mne|řet|hři|žel|psů|mst|4|7|17|1\d\d\D?|dřeva|dřev$)/;

    return $preposition;
}

1;

=over

=item Treex::Block::T2A::CS::VocalizePrepos

Vocalizes prepositions k,s,v,and z where neccessary.
Only the attribute C<form> is changed.

=back

=cut

# Copyright 2008,2016 Zdenek Zabokrtsky and Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
