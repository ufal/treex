package Treex::Block::A2T::ProjectSelectedWild;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {
    my ($self, $tnode) = @_;
    my @anodes = ($tnode->get_lex_anode, $tnode->get_aux_anodes);
    
    my ($anode) = grep {defined $_->wild->{check_comma_after}} @anodes;
    $tnode->wild->{check_comma_after} = $anode->wild->{check_comma_after} if (defined $anode);
}

1;
