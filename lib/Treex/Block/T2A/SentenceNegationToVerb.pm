package Treex::Block::T2A::SentenceNegationToVerb;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );


sub process_tnode {

    my ( $self, $tnode ) = @_;
    
    if ( $tnode->t_lemma eq '#Neg' ){
        $tnode->parent->set_gram_negation('neg1');
        $tnode->remove();
    }

    return;
}


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::SentenceNegationToVerb

=head1 DESCRIPTION

This block simply removes the sentence negation generated nodes and sets the corresponding negation grammateme
for the parent of the negation node. 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
