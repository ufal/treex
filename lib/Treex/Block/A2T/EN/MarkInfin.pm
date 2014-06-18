package Treex::Block::A2T::EN::MarkInfin;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::EN;

extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $anode = $tnode->get_lex_anode();

    # Fill $tnode->is_infin and fix $anode->get_iset('verbform') eq 'inf'
    if ( $anode && $anode->tag =~ /^VB[NG]?$/ ) {
        if ($self->is_infinitive($tnode, $anode)){
            $tnode->set_is_infin(1);
            $anode->set_iset('verbform', 'inf');
        } elsif ($anode->get_iset('verbform') eq 'inf') {
            $anode->set_iset('verbform', '');
        }
    }   
    
    return;
}

sub is_infinitive {
    my ($self, $tnode, $anode) = @_;

    # find the infinitive particle 'to'
    my @aux = $tnode->get_aux_anodes();
    my $to = first { $_->tag eq 'TO' } @aux;

    # require base form (possibly of an auxiliary)
    return 0 if $anode->tag ne 'VB' && !(any { $_->form =~ /^(be|have)$/i } @aux);
        
    # infinitive with the particle "to"
    if ( $to ){
        # require the particle 'to' in front of the main verb and in front of all auxiliaries
        return 1 if all { $_->ord > $to->ord } grep { $_->tag =~ /^[VM]/ } ($anode, @aux);
    }
    # try plain infinitives (with specified verbs)
    else {
        my ($tparent) = $tnode->get_eparents( { or_topological => 1 } );
        return 0 if !$tparent || $tparent->is_root;
        my $aparent = $tparent->get_lex_anode();
        return 0 if !$aparent;
        return 1 if Treex::Tool::Lexicon::EN::takes_bare_infin($aparent->lemma);
    }
    return 0;
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