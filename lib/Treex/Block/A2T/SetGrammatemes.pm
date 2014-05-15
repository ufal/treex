package Treex::Block::A2T::SetGrammatemes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %tag2sempos = (
    'adj-num'  => 'adj.quant.def',
    'adj-pron' => 'adj.pron.def.demon',
    'adj'      => 'adj.denot',
    'n-pron'   => 'n.pron.def.pers',
    'n-num'    => 'n.quant.def',
    'n'        => 'n.denot',
    'adv'      => 'adv.denot.grad.neg',
    'v'        => 'v',
);

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my ($anode) = $tnode->get_lex_anode();

    return if ( $tnode->nodetype ne 'complex' or !$anode );
    
    $self->set_sempos($tnode, $anode);

    return;
}

sub set_sempos {
    
    my ($self, $tnode, $anode) = @_;

    my $syntpos = $tnode->formeme;
    $syntpos =~ s/:.*//;

    my $subtype = $anode->is_pronoun ? 'pron' : ( $anode->is_numeral ? 'num' : '' );

    if ( $tag2sempos{ $syntpos . '-' . $subtype } ) {
        $tnode->set_gram_sempos( $tag2sempos{ $syntpos . '-' . $subtype } );
    }
    elsif ( $tag2sempos{$syntpos} ) {
        $tnode->set_gram_sempos( $tag2sempos{$syntpos} );
    }
    
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::SetGrammatemes

=head1 DESCRIPTION

A very basic, language-independent grammateme setting block for t-nodes. 

The only grammateme
currently supported is C<sempos>, which is set based on the formeme and Interset
part-of-speech features of the corresponding lexical a-node.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
