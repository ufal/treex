package Treex::Block::A2T::ES::SetGrammatemes;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::A2T::SetGrammatemes';

# TODO: add all possible verbal group signatures (or some equivalent rules)
my %SIG2GRAM = (
    # simple (synthetic) forms: present, past, participles, infinitive
    'LEX-inf'     => { 'diathesis' => 'act', 'tense' => 'nil',  'deontmod' => 'decl', 'verbmod' => 'nil' },
    'LEX-finpresind' => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-finpastind' => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-finfutind'  => { 'diathesis' => 'act', 'tense' => 'post', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-finpressub' => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'imp' }, ## common error of the analyzer
    'LEX-fincnd'     => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'cdn' },
    'LEX-finimp'     => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'imp' },

    # passive
    'ser-inf+LEX-partpast'     => { 'diathesis' => 'pas', 'tense' => 'nil',  'deontmod' => 'decl', 'verbmod' => 'nil' },
    'ser-finpresind+LEX-partpast' => { 'diathesis' => 'pas', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'ser-finpastind+LEX-partpast' => { 'diathesis' => 'pas', 'tense' => 'ant',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'ser-finfutind+LEX-partpast'  => { 'diathesis' => 'pas', 'tense' => 'post', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'ser-finpressub+LEX-partpast' => { 'diathesis' => 'pas', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'imp' }, ## common error of the analyzer
    'ser-fincnd+LEX-partpast'     => { 'diathesis' => 'pas', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'cdn' },
    'ser-finimp+LEX-partpast'     => { 'diathesis' => 'pas', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'imp' },

    # past forms with auxiliaries
    'haber-finpresind+LEX-partpast' => { 'diathesis' => 'act', 'tense' => 'ant', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'haber-finpastind+LEX-partpast' => { 'diathesis' => 'act', 'tense' => 'ant', 'deontmod' => 'decl', 'verbmod' => 'ind' },

    'haber-finpresind+ser-partpast+LEX-partpast' => { 'diathesis' => 'pas', 'tense' => 'ant', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'haber-finpastind+ser-partpast+LEX-partpast' => { 'diathesis' => 'pas', 'tense' => 'ant', 'deontmod' => 'decl', 'verbmod' => 'ind' },

    # modals (poder)
    'poder-finpresind+LEX-inf' => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'poss', 'verbmod' => 'ind' },
    'poder-finpastind+LEX-inf' => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'poss', 'verbmod' => 'ind' },
    'poder-finfutind+LEX-inf'  => { 'diathesis' => 'act', 'tense' => 'post', 'deontmod' => 'poss', 'verbmod' => 'ind' },
    'poder-finpressub+LEX-inf' => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'poss', 'verbmod' => 'imp' }, ## common error of the analyzer
    'poder-fincnd+LEX-inf'     => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'poss', 'verbmod' => 'cdn' },
    'poder-finimp+LEX-inf'     => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'poss', 'verbmod' => 'imp' },

    'poder-finpresind+ser-inf+LEX-partpast' => { 'diathesis' => 'pas', 'tense' => 'sim',  'deontmod' => 'poss', 'verbmod' => 'ind' },
    'poder-finpastind+ser-inf+LEX-partpast' => { 'diathesis' => 'pas', 'tense' => 'ant',  'deontmod' => 'poss', 'verbmod' => 'ind' },
    'poder-finfutind+ser-inf+LEX-partpast'  => { 'diathesis' => 'pas', 'tense' => 'post', 'deontmod' => 'poss', 'verbmod' => 'ind' },
    'poder-finpressub+ser-inf+LEX-partpast' => { 'diathesis' => 'pas', 'tense' => 'sim',  'deontmod' => 'poss', 'verbmod' => 'imp' }, ## common error of the analyzer
    'poder-fincnd+ser-inf+LEX-partpast'     => { 'diathesis' => 'pas', 'tense' => 'sim',  'deontmod' => 'poss', 'verbmod' => 'cdn' },
    'poder-finimp+ser-inf+LEX-partpast'     => { 'diathesis' => 'pas', 'tense' => 'sim',  'deontmod' => 'poss', 'verbmod' => 'imp' },

    # modals (deber)
    'deber-finpresind+LEX-inf' => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'deb',  'verbmod' => 'ind' },
    'deber-finpastind+LEX-inf' => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'deb',  'verbmod' => 'ind' },
    'deber-finfutind+LEX-inf'  => { 'diathesis' => 'act', 'tense' => 'post', 'deontmod' => 'deb',  'verbmod' => 'ind' },
    'deber-finpressub+LEX-inf' => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'deb',  'verbmod' => 'imp' }, ## common error of the analyzer
    'deber-fincnd+LEX-inf'     => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'deb',  'verbmod' => 'cdn' },
    'deber-finimp+LEX-inf'     => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'deb',  'verbmod' => 'imp' },

    'deber-finpresind+ser-inf+LEX-partpast' => { 'diathesis' => 'pas', 'tense' => 'sim',  'deontmod' => 'deb',  'verbmod' => 'ind' },
    'deber-finpastind+ser-inf+LEX-partpast' => { 'diathesis' => 'pas', 'tense' => 'ant',  'deontmod' => 'deb',  'verbmod' => 'ind' },
    'deber-finfutind+ser-inf+LEX-partpast'  => { 'diathesis' => 'pas', 'tense' => 'post', 'deontmod' => 'deb',  'verbmod' => 'ind' },
    'deber-finpressub+ser-inf+LEX-partpast' => { 'diathesis' => 'pas', 'tense' => 'sim',  'deontmod' => 'deb',  'verbmod' => 'imp' }, ## common error of the analyzer
    'deber-fincnd+ser-inf+LEX-partpast'     => { 'diathesis' => 'pas', 'tense' => 'sim',  'deontmod' => 'deb',  'verbmod' => 'cdn' },
    'deber-finimp+ser-inf+LEX-partpast'     => { 'diathesis' => 'pas', 'tense' => 'sim',  'deontmod' => 'deb',  'verbmod' => 'imp' },
);

override 'set_verbal_grammatemes' => sub {
    my ( $self, $tnode, $anode ) = @_;

    my $sig = $self->get_verbal_group_signature( $tnode, $anode );
    my $gram = $SIG2GRAM{$sig};

    if ($gram) {
        while ( my ( $gram_name, $gram_val ) = each %$gram ) {
            $tnode->set_attr( 'gram/' . $gram_name, $gram_val );
        }
    }
    else {
        my $id = $tnode->id . ' -- ' . join(' ', map { lc $_->form } grep { $_->is_verb } $tnode->get_anodes( { ordered => 1 } ) );
        log_warn( "No grammatemes found for verbal group signature `$sig': $id");
    }
    return 1;
};

sub get_form_signature {
    my ( $self, $anode ) = @_;
    return $anode->get_iset('verbform') . $anode->get_iset('tense') . $anode->get_iset('mood');
}

# returns de-lexicalized signature of all verb forms in the verbal group (to be mapped to grammatemes)
sub get_verbal_group_signature {
    my ( $self, $tnode, $lex_anode ) = @_;
    my @sig = ();
    foreach my $anode ( grep { $_->is_verb } $tnode->get_anodes( { ordered => 1 } ) ) {

        # de-lexicalize
        my $lemma = $anode == $lex_anode ? 'LEX' : $anode->lemma;

        # put finite verb first at all times (handle word order change in some embedded clauses)
        if ( $anode->match_iset( 'verbform' => 'fin' ) ) {
            unshift @sig, $lemma . '-' . $self->get_form_signature($anode);
        }
        else {
            push @sig, $lemma . '-' . $self->get_form_signature($anode);
        }
    }

    #log_info( join( ' ', map { $_->form } $tnode->get_anodes( { ordered => 1 } ) ) . ' -- ' . join( '+', @sig ) );
    return join( '+', @sig );
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::ES::SetGrammatemes

=head1 DESCRIPTION

Spanish-specific settings for grammatemes values.

Currently, verbal grammatemes are set according to the shape of the verbal group.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
