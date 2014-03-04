package Treex::Block::A2T::CS::SetMissingFunctors;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

# Most common functors for the given POS based on PDT training data, unless specified otherwise
Readonly my $POS_MAP => {
    'A2'  => 'FPHR',
    'A3'  => 'RSTR',
    'AA'  => 'RSTR',
    'AC'  => 'PAT',
    'AG'  => 'RSTR',
    'AM'  => 'RSTR',
    'AO'  => 'APP',     # LOC is more common
    'AU'  => 'APP',
    'C='  => 'RSTR',
    'C-'  => 'RSTR',   # just for Slovak
    'C?'  => 'RSTR',
    'Ca'  => 'RSTR',
    'Cd'  => 'RSTR',
    'Ch'  => 'PAT',
    'Cl'  => 'RSTR',
    'Cn'  => 'RSTR',
    'Co'  => 'THO',
    'Cr'  => 'RSTR',
    'Cv'  => 'THO',
    'Cw'  => 'RSTR',
    'Cy'  => 'PAT',
    'C}'  => 'RSTR',
    'Db'  => 'TWHEN',
    'Dg'  => 'MANN',
    'II'  => 'PAT',
    'J*'  => 'OPER',
    'J,'  => 'RHEM',    # ??? and PREC are more common
    'J^'  => 'PREC',    # CONJ is more common
    'NN'  => 'PAT',
    'P1'  => 'APP',
    'P4'  => 'ACT',
    'P5'  => 'LOC',
    'P6'  => 'PAT',     # LOC is more common
    'P7'  => 'PAT',     # ??? is more common
    'P8'  => 'APP',
    'P9'  => 'LOC',
    'PD'  => 'RSTR',
    'PE'  => 'ACT',
    'PH'  => 'PAT',
    'PJ'  => 'ACT',
    'PK'  => 'ACT',
    'PL'  => 'RSTR',
    'PP'  => 'PAT',
    'PQ'  => 'PAT',
    'PS'  => 'APP',
    'PW'  => 'RSTR',
    'PZ'  => 'RSTR',
    'RF'  => 'FPHR',    # CNCS is more common
    'RR'  => 'FPHR',    # ??? is more common
    'RV'  => 'FPHR',    # ??? is more common
    'TT'  => 'RHEM',
    'VB'  => 'PRED',
    'Vc'  => 'ID',
    'Ve'  => 'COMPL',
    'Vf'  => 'PAT',
    'Vi'  => 'PRED',
    'Vm'  => 'COMPL',
    'Vp'  => 'PRED',
    'Vq'  => 'EFF',
    'Vs'  => 'PRED',
    'X@'  => 'FPHR',
};

sub process_tnode {
    my ( $self, $tnode ) = @_;

    if ( !defined $tnode->functor || $tnode->functor eq '???' ) {

        my $anode = $tnode->get_lex_anode();
        return if ( !$anode || !$anode->tag );

        my $functor = $POS_MAP->{ substr( $anode->tag, 0, 2 ) };

        if ( any { $_->is_member } $tnode->get_children() ) {
            $functor = 'CONJ';
        }
        $tnode->set_functor($functor || '???');
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::CS::SetMissingFunctors

=head1 DESCRIPTION

Set all functors that weren't recognized (their value is '???' or undef)
to the most common functor for the POS of the corresponding lex-anode.
If the unrecognized node actually has coordination/apposition members,
its functors is hard-set to 'CONJ'.
If no functor is found in the POS mapping and no co/ap members are found,
the functor is assigned a special '???' value.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
