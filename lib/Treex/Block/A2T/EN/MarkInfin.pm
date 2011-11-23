package Treex::Block::A2T::EN::MarkInfin;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $tnode ) = @_;
    my $anode = $tnode->get_lex_anode();

    return if ( !$anode );

    if ( $anode->tag =~ /^VB[NG]?$/ ) {
        my @aux = $tnode->get_aux_anodes();
        my $to = first { $_->tag eq 'TO' } @aux;    # find the infinitive particle 'to'

        return if ( !$to );

        if (( $anode->ord > $to->ord )    # require the particle 'to' in front of the main verb
            && ( all { $_->ord > $to->ord } grep { $_->tag =~ /^[VM]/ } @aux )    # and in front of all auxiliaries
            && ( $anode->tag eq 'VB' || any { $_->form =~ /^(be|have)$/i } @aux ) # require base form (possibly of an auxiliary)
            )
        {
            $tnode->set_is_infin(1);
        }
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::CS::MarkInfin

=head1 DESCRIPTION

EnglishT nodes corresponding to non-finite verbal expressions (with the particle "to") are marked
by value 1 in the C<is_infin> attribute.

=head1 TODO

Mark also infinitives without the particle "to" ?

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.