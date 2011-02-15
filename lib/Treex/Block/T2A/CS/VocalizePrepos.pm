package Treex::Block::T2A::CS::VocalizePrepos;
use Moose;
use Treex::Moose;
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

    return 'ke' if $preposition eq 'k' and $follower =~ /^(k|g|sp|sn|zv|zm|sc|zl|sl|sk|zp|zk|šk|zd|zt|zb|zr|sv|mn|vš|vs|ct|sj|dv|zř|zh|vč|šp|lá|šť|mř|zc|št|vk|sta|vzn|stu|vzd|smí|stě|dnu|vzo|sti|sty|sro|dnů|sdr|sbl|sbí|čty|zná)/;

    return 've' if $preposition eq 'v' and $follower =~ /^(v|f|st|sp|čt|sk|sv|kt|fr|fi|sl|sn|fu|zl|fo|šv|zn|zp|šk|wa|ii|hř|dv|zd|sb|šp|sh|št|zb|fa|fá|rw|zk|wi|tm|jm|we|fs|fy|fó|žď|hv|gy|mz|žd|šl|gi|zh|sj|zt|žr|šr|cv|sw|sro|sml|tří|tva|srá|obž|zví|psa|smr|žlu|sca|zrů|sce|zvo|zme|mně$|mne$)/;

    return 'se' if $preposition eq 's' and $follower =~ /^(s|z|kt|vz|vš|mn|šk|že|čt|šv|št|ps|vs|šp|ži|cm|ža|ct|cv|dž|šl|še|bý|čle|jmě|ple|šam|lst|prs|dvě|dře|7|17$|1\d\d\D?)/;

    return 'ze' if $preposition eq 'z' and $follower =~ /^(s|z|kt|dn|šk|vs|šv|vš|št|šu|dř|mz|ži|tm|kb|šp|pé|ša|kč|hv|nk|ši|rt|lh|ký|ža|lv|šl|žď|žl|hry|vzd|tří|rom|jmě|šes|mne|řet|hři|lan|žel|pan|wil|dou|thp|pak|půt|cih|brá|hrd|mik|idy|psů|mst|mag|vas|4|7|17|1\d\d\D?)/;

    return $preposition;
}

1;

=over

=item Treex::Block::T2A::CS::VocalizePrepos

Vocalizes prepositions k,s,v,and z where neccessary.
Only the attribute C<form> is changed.

=back

=cut

# Copyright 2008 Zdenek Zabokrtsky and Martin Popel

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
