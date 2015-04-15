package Treex::Block::T2T::CS2CS::FormemeTLemmaAgreement;
use Moose;
use Treex::Tool::LM::TreeLM;

extends 'Treex::Block::T2T::FormemeTLemmaAgreement';


override 'agree' => sub {
    my ( $self, $pos, $formeme ) = @_;

    return 1 if ( $pos =~ /^(V|X)$/       and $formeme =~ /^v/ );
    return 1 if ( $pos =~ /^(N|A|C|P|X)$/ and $formeme =~ /^(n|adj:poss)/ );    
    return 1 if ( $pos =~ /^(A|C|P|X)$/   and $formeme =~ /^adj/ );
    return 1 if ( $pos =~ /^(D|X)$/       and $formeme =~ /^adv/ );    
    return 1 if ( $pos =~ /^(J|I|T|X|Z)$/ and $formeme eq 'x' );
    
    return 1 if Treex::Tool::LM::TreeLM::is_pos_and_formeme_compatible($pos, $formeme);    

    return 0;
};

1;