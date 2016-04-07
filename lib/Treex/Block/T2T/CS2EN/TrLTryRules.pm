package Treex::Block::T2T::CS2EN::TrLTryRules;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

#TODO These hacks should be removed from here and added to the translation dictionary
Readonly my %QUICKFIX_TRANSLATION_OF => (

    q{„} => q{"}, # TODO: or should we use typographic “…” quotes?
    q{“} => q{"},

    #q{skype}      => 'Skype|NNP',
    #q{Skype}      => 'Skype|NNP',
    'opakovač'        => 'repeater|noun',
    'nabootovat'       => 'boot|verb',
    'hacknutý'        => 'hacked|adj',
    'naskenovat'       => 'scan|verb',
    'nascanovat'       => 'scan|verb',
    'odmrazit'         => 'unfreeze|verb',
    'čeština'        => 'Czech|noun',
    'virální'        => 'viral|adj',
    'lajkování'      => 'liking|noun',
    'DNS'              => 'DNS|noun',
    'rebélie'         => 'rebellion|noun',
    'umírněný'      => 'moderate|adj',
    'umírnění'      => 'moderation|noun',
    'Libyjec'          => 'Libyan|noun',
    'Aláh'            => 'Allah|noun',
    'vyhánění'      => 'expelling|noun',
    'odpadat'          => 'fall_off|verb',
    'zištný'         => 'selfless|adj',
    'šaria'           => 'Sharia|noun',
    'dluhopisový'     => 'debit|noun',
    'eurozóna'        => 'Eurozone|noun',
    'mezikvartálně'  => 'between_quarters|adj',
    'mezičtvrtletně' => 'between_quarters|adj',
    'přepočtený'    => 'recalculated|adj',
    '10letý'          => '10-year|adj',
    'uhájit'          => 'defend|verb',
    'šampionát'      => 'championship|noun',
    'postupový'       => 'progress|adj',
    'černohorec'      => 'Montenegrin|noun',
    'smolař'          => 'underdog|noun',
    'půlící'        => 'mid-field|adj',
    'precizně'        => 'precisely|adv',
    'provolávat'      => 'proclaim|verb',
    'Isfahánský'     => 'Isfahan|adj',
    'Isfahán'         => 'Isfahan|noun',
    'uzenina'          => 'sausage|noun',
    'příklon'        => 'tendency|noun',
    'markantní'       => 'significant|adj',
    'stylista'         => 'stylist|noun',
    'našlapaný'      => 'packed|adj',
    'zjemnit'          => 'soften|verb',
    'obleček'         => 'cloth|noun',
    'nastajlovat'      => 'style|verb',
    'manažerka'       => 'manager|noun',
    'klipsa'           => 'clip-on|noun',
    'podlepit'         => 'underlay|verb',
    'focení'          => 'photoshoot|noun',
    'vyslechnout_si'   => 'hear|verb',
    'vyslechnout'      => 'hear|verb',
    'šichta'          => 'work|noun',
    'závodění'      => 'racing|noun',
    'proběhnout se'   => 'run|verb',
    'arkádový'       => 'arcade|adj',
    'světoborný'     => 'world-shattering|adj',
    'zpestřit'        => 'liven_up|verb',
    'nasázet'         => 'place|verb',
    'solidnost'  => 'solidity|noun',
    'vytěžování' => 'exploiting|noun',
    'předivo' => 'fabric|noun',
    'zaujatost' => 'bias|noun',
    'umisťující' => 'placing|adj',
    'skórovat' => 'score|verb',
    'chátrat' => 'decay|verb',
    'památkový' => 'monument|adj',
    'vrýt'  => 'engrave|verb',
    'napadrť' => 'to_smithereens|adv',
    'pepřový' => 'pepper|adj',
    'hantýrka' => 'jargon|noun',
    'snadnost' => 'ease|noun',
    'iránský' => 'Iranian|adj',
    'voluntaristický' => 'voluntary|adj',
    'sběratelka' => 'collector|noun',
    'sběratel' => 'collector|noun',
    

    # TODO: the following is QTLeap-specific -- it should not be used elsewhere
    'písmo'        => 'font|noun',
    'připojit_se'  => 'connect|verb',
    'kontrolka'     => 'light|noun',
    'plocha'        => 'desktop|noun',
    'vstup'         => 'input|noun',
    'mezera'        => 'space|noun',
    'prohlížení' => 'browsing|noun',
    'prohlížeč'  => 'browser|noun',
    'cookies'       => 'cookies|noun',
    'doplněk'      => 'add-on|noun',
    'rozšíření' => 'add-on|noun',
);

sub process_tnode {
    my ( $self, $trg_tnode ) = @_;

    # Skip nodes that were already translated by other rules
    return if $trg_tnode->t_lemma_origin !~ /^(clone|lookup)/;

    my $src_tnode = $trg_tnode->src_tnode or return;
    my $lemma_and_pos = $self->get_lemma_and_pos( $src_tnode, $trg_tnode );
    if ( defined $lemma_and_pos ) {
        my ( $trg_tlemma, $m_pos ) = split /\|/, $lemma_and_pos;
        $trg_tnode->set_t_lemma($trg_tlemma);
        $trg_tnode->set_t_lemma_origin('rule-TrLTryRules');
        $trg_tnode->set_attr( 'mlayer_pos', $m_pos ) if $m_pos;
    }
    return;
}

sub get_lemma_and_pos {
    my ( $self, $src_tnode, $trg_tnode ) = @_;
    my ( $src_tlemma, $src_formeme ) = $src_tnode->get_attrs(qw(t_lemma formeme));

    my $src_anode = $src_tnode->get_lex_anode();
    if ($src_anode) {
        return 'Skype|NNP' if $src_anode->form =~ /^skyp[eu]m?$/;

        # TODO not all reflexive pronouns should be deleted (but must in Batch1q yes).
        if ( $src_anode->lemma =~ /^s[ei]_/ ) {
            $trg_tnode->remove( { children => 'rehang' } );
            return;
        }
    }

    # Don't translate other t-lemma substitutes (like #PersPron, #Cor, #QCor, #Rcp)
    return $src_tlemma if $src_tlemma =~ /^#/;

    # Prevent some errors/misses in dictionaries
    my $lemma_and_pos = $QUICKFIX_TRANSLATION_OF{$src_tlemma};
    return $lemma_and_pos if $lemma_and_pos;

    # If no rules match, get_lemma_and_pos has not succeeded.
    return undef;
}

1;

__END__

=over

=item Treex::Block::T2T::CS2EN::TrLTryRules

Try to apply some hand written rules for t-lemma translation.
If succeeded, t-lemma is filled and atributte C<t_lemma_origin> is set to I<rule>.

=back

=cut

# Copyright 2015 Martin Popel
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

