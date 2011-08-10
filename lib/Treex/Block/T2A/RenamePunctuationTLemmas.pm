package Treex::Block::T2A::RenamePunctuationTLemmas;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

Readonly my $CONVERT_TABLE => {
    '#Amp'       => '&',      # ampersand
    '#Percnt'    => '%',      # per cent
    '#Ast'       => '*',      # asterisk
    '#Period'    => '.',      # period
    '#Period3'   => '...',    # three periods
    '#Colon'     => ':',      # colon
    '#Comma'     => ',',      # comma
    '#Semicolon' => ';',      # semicolon
    '#Dash'      => '-',      # hyphen
    '#Dash'      => '–',    # dash
    '#Slash'     => '/',      # slash
    '#Bracket'   => '(',      # (left) bracket, since right bracket is not present on the t-layer
};    # the t-lemmas (as in PDT) and the corresponding a-lemmas

sub process_tnode {

    my ( $self, $tnode ) = @_;

    if ( $CONVERT_TABLE->{ $tnode->t_lemma } ) {
        $tnode->set_t_lemma( $CONVERT_TABLE->{ $tnode->t_lemma } );
    }
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::RenamePunctuationTLemmas

=head1 DESCRIPTION

This block renames the punctuation t-lemmas from their '#-' form in PDT/PEDT to their a-lemma form as used
in Treex/TectoMT. 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
