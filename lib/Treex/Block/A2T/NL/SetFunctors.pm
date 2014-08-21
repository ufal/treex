package Treex::Block::A2T::NL::SetFunctors;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::SetFunctorsRules';

override '_build_formeme2functor' => sub {
    return {
        'n:obj'         => 'PAT',
        'n:obj1'        => 'ADDR',
        'n:obj2'        => 'PAT',
        'n:voor+X'      => 'BEN',
        'n:met+X'       => 'ACMP',
        'n:poss'        => 'APP',
        'n:van+X'       => 'APP',
        'adj:attr'      => 'RSTR',
        'v:attr'        => 'RSTR',
        'v:als+fin'     => 'COND',
        'v:of+fin'      => 'COND',
        'n:door+X'      => 'MEANS',
        'n:uit+X'       => 'DIR1',
        'n:naar+X'      => 'DIR3',
        'n:over+X'      => 'DIR3',
        'n:aan+X'       => 'LOC',
        'n:in+X'        => 'LOC',
        'n:op+X'        => 'LOC',
        'n:onder+X'     => 'LOC',
        'n:binnen+X'    => 'LOC',
        'n:boven+X'     => 'LOC',
        'n:achter+X'    => 'LOC',
        'n:binnen+X'    => 'LOC',
        'v:omdat+fin'   => 'CAUS',
        'v:om+fin'      => 'CAUS',
        'v:vanwege+fin' => 'CAUS',
        'v:tot+fin'     => 'TTILL',
        'v:totdat+fin'  => 'TTILL',
        'v:nadat+fin'   => 'TWHEN',
        'v:voordat+fin' => 'TWHEN',
        'v:dat+fin'     => 'EFF',
        'v:zoals+fin'   => 'MANN',
        'adv'           => 'MANN',
        'v:rc'          => 'RSTR',
        'adj:compl'     => 'PAT',
        'n:attr'        => 'RSTR',
    };
};

override '_build_afun2functor' => sub {
    return {
        'Apos' => 'APPS',
    };
};

override '_build_lemma2functor' => sub {
    return {
        'waneer'        => 'TWHEN',
        'nu'            => 'TWHEN',
        'momenteel'     => 'TWHEN',
        'binnenkort'    => 'TWHEN',
        'weldra'        => 'TWHEN',
        'vroeg'         => 'TWHEN',
        'laat'          => 'TWHEN',
        'straks'        => 'TWHEN',
        'thans'         => 'TWHEN',
        'dan'           => 'TWHEN',
        'altijd'        => 'TWHEN',
        'niet'          => 'RHEM',
        'maar'          => 'RHEM',
        'pas'           => 'RHEM',
        'net'           => 'RHEM',
        'juist'         => 'RHEM',
        'zojuist'       => 'RHEM',
        'zonet'         => 'RHEM',
        'toch'          => 'RHEM',
        'slechts'       => 'RHEM',
        'even'          => 'RHEM',
        'zelfs'         => 'RHEM',
        'bijna'         => 'EXT',
        'ook'           => 'RHEM',
        'nog'           => 'RHEM',
        'beide'         => 'RSTR',
        'allebei'       => 'RSTR',
        'beiden'        => 'RSTR',
        'snel'          => 'EXT',
        'vlot'          => 'EXT',
        'vlug'          => 'EXT',
        'langzaam'      => 'EXT',
        'traag'         => 'EXT',
        'veel'          => 'EXT',
        'zeer'          => 'EXT',
        'heel'          => 'EXT',
        'uiterst'       => 'EXT',
        'voornamelijk'  => 'EXT',
        'vooral'        => 'EXT',
        'hoofdzakelijk' => 'EXT',
        'erg'           => 'EXT',
        'behoorlijk'    => 'EXT',
    };
};

override '_build_aux2functor' => sub {
    return {
        'dan'       => 'CPR',
        'als'       => 'CPR',
        'aangezien' => 'REG',
        'gezien'    => 'REG',
        'sinds'     => 'TSIN',
        'vanaf'     => 'TSIN',
        'volgens'   => 'REG',
        'ondanks'   => 'CNCS',
        'trots'     => 'CNCS',
        'toen'      => 'TWHEN',
        'zodra'     => 'TWHEN',
    };
};

override '_build_temporal_nouns' => sub {
    return

        {
        map { $_ => 1 }
            qw(
            zondag maandag dinsdag woensdag donderdag vrijdag zaterdag
            januari februari maart april mei juni juli august september oktober november december
            lente voorjaar zomer herfst najaar winter
            jaar maand week dag uur minuut
            vandaag morgen vanmorgen gisteren
            avond middag nacht
            tijd termijn epoch epoche tijdperk era tijdvak tijdruimte
            )
        };

};

has '+prep_when'  => ( default => '^(op|aan|in|binnen)$' );
has '+prep_since' => ( default => '^(sinds|van|vanaf)$' );
has '+prep_till'  => ( default => '^(tot|voor)$' );

override 'try_rules' => sub {
    my ( $self, $tnode ) = @_;
    my ($tparent) = $tnode->get_eparents( { or_topological => 1 } );

    if ( $tnode->formeme eq 'n:subj' and $tparent and $tparent->formeme // '' =~ /^v/ ) {
        if ( ( $tnode->get_parent->gram_diathesis // '' ) eq 'pas' ) {
            return 'PAT';
        }
        return 'ACT';
    }
    return;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2T::NL::SetFunctors

=head1 DESCRIPTION

A very basic block that sets functors in Dutch using several simple rules.
=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
