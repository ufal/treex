package Treex::Block::A2A::CS::FixNounAdjectiveAgreement;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g ) = @_;

    if ($dep->afun eq 'Atr'
        && $g->{tag} =~ /^N/ && $d->{tag} =~ /^A|(P[8DLSWZ])|(C[dhkrwz])/    # syntactical adjectives
        && lc( $dep->form ) ne 'to'                                          # do not fix 'to' ('it')
        && $gov->ord > $dep->ord
        && ($g->{gen}
            . $g->{num}
            . $g->{case}
            ne $d->{gen} . $d->{num} . $d->{case}
        )
        )
    {

        my $new_gnc = $g->{gen} . $g->{num} . $g->{case};
        substr $d->{tag}, 2, 3, $new_gnc;
        $self->logfix1( $dep, "NounAdjectiveAgreement" );
        $self->regenerate_node( $dep, $d->{tag} );
        $self->logfix2($dep);
    }
}

1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixNounAdjectiveAgreement

=head1 DESCRIPTION

Fixing agreement between noun and adjective.

=head1 AUTHORS

David Mareček <marecek@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This file is distributed under the GNU General Public License v2.
See $TMT_ROOT/README for details on Treex licencing.
