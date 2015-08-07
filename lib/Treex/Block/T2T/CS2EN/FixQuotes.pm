package Treex::Block::T2T::CS2EN::FixQuotes;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_tnode {

    my ( $self, $tnode ) = @_;

    $tnode->set_t_lemma('”') if ( $tnode->t_lemma eq '“' );
    $tnode->set_t_lemma('“') if ( $tnode->t_lemma eq '„' );
    $tnode->set_t_lemma('’') if ( $tnode->t_lemma eq '‘' );
    $tnode->set_t_lemma('‘') if ( $tnode->t_lemma eq '‚' );
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2T::CS2EN::FixQuotes

=head1 DESCRIPTION

Translate Unicode Czech quotation marks into English ones.

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
