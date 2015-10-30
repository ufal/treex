package Treex::Block::A2T::PT::SetGrammatemes;
use Moose;
use Treex::Core::Common;
use List::Pairwise qw(mapp);
extends 'Treex::Block::A2T::SetGrammatemes';

sub set_verbal_grammatemes {
    my ( $self, $tnode, $anode ) = @_;

    # TODO: it's intended for modal verbs, but it is not clear whether it should apply also to other complex verb forms
    foreach my $aux_verb (grep {$_->iset->pos eq "verb"} $tnode->get_aux_anodes) {
   
        $self->set_grammatemes_from_iset( $tnode, $aux_verb );
    }

}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::SetGrammatemes

=head1 DESCRIPTION

A very basic, language-independent grammateme setting block for t-nodes. 
Grammatemes are set based on the Interset features (and formeme)
of the corresponding lexical a-node.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
