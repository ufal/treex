package Treex::Block::A2T::EN::SetMissingFunctors;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

# Based on sections 02-21 of PEDT, unless indicated otherwise
Readonly my $POS_MAP => {
    '#'     => 'PAT',
    '$'     => 'PAT',
    ','     => 'RHEM',
    '-RRB-' => 'RHEM',    # ??? is more common
    '.'     => 'RHEM',    # ??? is more common
    ':'     => 'PREC',    # ??? is more common
    'CC'    => 'CONJ',
    'CD'    => 'RSTR',
    'DT'    => 'RSTR',
    'FW'    => 'FPHR',
    'IN'    => 'FPHR',    # ??? is more common
    'JJ'    => 'RSTR',
    'JJR'   => 'RSTR',
    'JJS'   => 'RSTR',
    'LS'    => 'PREC',
    'MD'    => 'PRED',    # ??? is more common
    'NN'    => 'PAT',
    'NNP'   => 'NE',
    'NNPS'  => 'NE',
    'NNS'   => 'PAT',
    'PDT'   => 'RSTR',
    'POS'   => 'PRED',
    'PRP'   => 'ACT',
    'PRP$'  => 'APP',
    'RB'    => 'EXT',
    'RBR'   => 'TWHEN',
    'RBS'   => 'EXT',
    'SYM'   => 'PREC',
    'TO'    => 'FPHR',    # ??? is more common
    'UH'    => 'PARTL',
    'VB'    => 'PAT',
    'VBD'   => 'PRED',
    'VBG'   => 'RSTR',
    'VBN'   => 'PRED',
    'VBP'   => 'PRED',
    'VBZ'   => 'PRED',
    'WDT'   => 'ACT',
    'WP'    => 'ACT',
    'WP$'   => 'APP',
    'WRB'   => 'LOC',     # ??? is more common
};

sub process_tnode {

    my ( $self, $tnode ) = @_;

    return if ( $tnode->functor ne '???' );

    my $anode = $tnode->get_lex_anode();
    return if ( !$anode || !$anode->tag );

    my $functor = $POS_MAP->{ $anode->tag };

    if ( any { $_->is_member } $tnode->get_children() ) {
        $functor = 'CONJ';
    }
    $tnode->set_functor($functor) if ($functor);
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::EN::SetMissingFunctors

=head1 DESCRIPTION

Set all functors that weren't recognized (their value is '???') to the most common functor for the POS
of the corresponding lex-anode. If the unrecognized node actually has coordination/apposition members,
its functors is hard-set to 'CONJ'.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
