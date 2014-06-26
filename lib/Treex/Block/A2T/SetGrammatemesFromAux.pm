package Treex::Block::A2T::SetGrammatemesFromAux;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# my @RULES = (
#     'adjtype=art definiteness=def' => 'definiteness=definite',
#     'adjtype=art definiteness=ind' => 'definiteness=indefinite',
# );

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my @anodes = $tnode->get_aux_anodes();
    return if !@anodes;
    return if $tnode->nodetype ne 'complex';

    foreach my $anode (@anodes) {
        if ($anode->iset->adjtype eq 'art'){
            my $d = $anode->iset->definiteness;
            $tnode->set_gram_definiteness('definite') if $d eq 'def';
            $tnode->set_gram_definiteness('indefinite') if $d eq 'ind';
        }
    }

    return;
}


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::SetGrammatemesFromAux

=head1 DESCRIPTION

A very basic, language-independent grammateme setting block for t-nodes. 
Grammatemes are set based on the Interset features (and formeme)
of the corresponding auxiliary a-nodes.

So far, only definiteness is handled (i.e. definite and indefinite articles).

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
