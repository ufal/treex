package Treex::Block::A2T::EN::MarkInfin;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::EN;

extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $tnode ) = @_;
    my $anode = $tnode->get_lex_anode();

    return if ( !$anode );

    if ( $anode->tag =~ /^VB[NG]?$/ ) {
        
        # find the infinitive particle 'to'
        my @aux = $tnode->get_aux_anodes();
        my $to = first { $_->tag eq 'TO' } @aux;

         # require base form (possibly of an auxiliary)
        return if ( $anode->tag ne 'VB' && !(any { $_->form =~ /^(be|have)$/i } @aux) );
        
        # infinitive with the particle "to"
        if ( $to ){

            # require the particle 'to' in front of the main verb and in front of all auxiliaries
            if ( all { $_->ord > $to->ord } grep { $_->tag =~ /^[VM]/ } ($anode, @aux) ){
                $tnode->set_is_infin(1);
                return;
            }
        }
        # try plain infinitives (with specified verbs)
        else {

            my ($tparent) = $tnode->get_eparents( { or_topological => 1 } );
            return if (!$tparent || $tparent->is_root );
            my $aparent = $tparent->get_lex_anode();
            return if (!$aparent);
        
            if ( Treex::Tool::Lexicon::EN::takes_bare_infin( $aparent->lemma ) ){
                $tnode->set_is_infin(1);
                return;
            }
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

English t-nodes corresponding to non-finite verbal expressions (with or without the particle "to") are marked
by value 1 in the C<is_infin> attribute.

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.