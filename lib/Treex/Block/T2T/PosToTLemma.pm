package Treex::Block::T2T::PosToTLemma;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $anode = $tnode->get_lex_anode or return;
    my ($pos) = ( $anode->tag =~ /^(.)/ );
    if (defined $pos){
        $tnode->set_t_lemma($tnode->t_lemma . "#$pos");
        $tnode->set_attr('mlayer_pos', $pos);
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::PosToTLemma - add PoS as a suffix to t_lemma

=head1 DESCRIPTION

Attribute mlayer_pos is a temporary solution to encode morphological part-of-speech tag into t-layer.
This simple block creates t_lemmas with added # and mlayer_pos (e.g. pes#N).

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
