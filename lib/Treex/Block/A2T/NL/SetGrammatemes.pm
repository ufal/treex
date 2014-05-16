package Treex::Block::A2T::NL::SetGrammatemes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2T::SetGrammatemes';

# TODO: add all possible verbal group signatures (or some equivalent rules)
my %SIG2GRAM = (
    'LEX-finpres'                       => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-finpast'                       => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-partpres'                       => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-partpast'                       => { 'diathesis' => 'pas', 'tense' => 'ant',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'moeten-finpres+LEX-inf'            => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'hrt',  'verbmod' => 'ind' },
    'moeten-finpast+LEX-inf'            => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'hrt',  'verbmod' => 'ind' },
    'kunnen-finpres+LEX-inf'            => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'poss', 'verbmod' => 'ind' },
    'kunnen-finpast+LEX-inf'            => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'poss', 'verbmod' => 'ind' },
    'mogen-finpres+LEX-inf'             => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'perm', 'verbmod' => 'ind' },
    'mogen-finpast+LEX-inf'             => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'perm', 'verbmod' => 'ind' },
    'willen-finpres+LEX-inf'            => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'vol',  'verbmod' => 'ind' },
    'willen-finpast+LEX-inf'            => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'vol',  'verbmod' => 'ind' },
    'zullen-finpres+LEX-inf'            => { 'diathesis' => 'act', 'tense' => 'post', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'zullen-finpast+LEX-inf'            => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'cdn' },
    'hebben-finpres+LEX-partpast'       => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'hebben-finpast+LEX-partpast'       => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'worden-finpres+LEX-partpast'       => { 'diathesis' => 'pas', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'worden-finpast+LEX-partpast'       => { 'diathesis' => 'pas', 'tense' => 'ant',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'zullen-finpast+moeten-inf+LEX-inf' => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'hrt',  'verbmod' => 'cdn' },
    'zullen-finpast+willen-inf+LEX-inf' => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'vol',  'verbmod' => 'cdn' },
    'zullen-finpast+kunnen-inf+LEX-inf' => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'poss', 'verbmod' => 'cdn' },
    'zullen-finpast+mogen-inf+LEX-inf'  => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'perm', 'verbmod' => 'cdn' },
);

override 'set_verbal_grammatemes' => sub {
    my ( $self, $tnode, $anode ) = @_;

    my $gram = $SIG2GRAM{ $self->get_verbal_group_signature( $tnode, $anode ) };

    if ($gram) {
        while ( my ( $gram_name, $gram_val ) = each %$gram ) {
            $tnode->set_attr( 'gram/' . $gram_name, $gram_val );
        }
    }
    return 1;
};

sub get_form_signature {
    my ( $self, $anode ) = @_;
    return $anode->get_iset('verbform') . $anode->get_iset('tense');
}

sub get_verbal_group_signature {
    my ( $self, $tnode, $lex_anode ) = @_;
    my @sig = ();
    foreach my $anode ( grep { $_->is_verb } $tnode->get_anodes( { ordered => 1 } ) ) {
        if ( $anode == $lex_anode ) {
            push @sig, 'LEX-' . $self->get_form_signature($anode);
        }
        else {
            push @sig, $anode->lemma . '-' . $self->get_form_signature($anode);
        }
    }
    #log_info( join( ' ', map { $_->form } $tnode->get_anodes( { ordered => 1 } ) ) . ' -- ' . join( '+', @sig ) );
    return join( '+', @sig );
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::NL::SetGrammatemes

=head1 DESCRIPTION

Dutch-specific settings for grammatemes values.

Currently, verbal grammatemes are set according to the shape of the verbal group.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
