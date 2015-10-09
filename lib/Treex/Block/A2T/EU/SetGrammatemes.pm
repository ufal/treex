package Treex::Block::A2T::EU::SetGrammatemes;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::A2T::SetGrammatemes';

# TODO: add all possible verbal group signatures (or some equivalent rules)
my %SIG2GRAM = (
    # simple (synthetic) forms: present, past, participles, infinitive
    'LEX-imp'               => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'imp' },
    'LEX-perf'              => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'imp' },
    'LEX-part'              => { 'diathesis' => 'act', 'tense' => 'nil',  'deontmod' => 'decl', 'verbmod' => 'nil' },
    'LEX-ger'               => { 'diathesis' => 'act', 'tense' => 'nil',  'deontmod' => 'decl', 'verbmod' => 'nil' },
    'LEX-pro'               => { 'diathesis' => 'act', 'tense' => 'nil',  'deontmod' => 'decl', 'verbmod' => 'nil' },
    'LEX-fin'               => { 'diathesis' => 'act', 'tense' => 'nil',  'deontmod' => 'decl', 'verbmod' => 'nil' },
    'LEX-'                  => { 'diathesis' => 'act', 'tense' => 'nil',  'deontmod' => 'decl', 'verbmod' => 'nil' },

    ## da
    'LEX-finpresind'        => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    ## dagokien
    'LEX-finpressub'        => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'ind' }, ## error in the analysis. Present + relative marker
    ## zen
    'LEX-finpastind'        => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    ## luke
    'LEX-finprescnd'        => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'cdn' },
    ## liteke???
    'LEX-finpastpot'        => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'poss', 'verbmod' => 'ind' },

    ### etortzen da -> present
    'LEX-+izan-finpresind'     => { 'diathesis' => 'act', 'tense' => 'sim', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-+izan-presind'        => { 'diathesis' => 'act', 'tense' => 'sim', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-+ukan-finpresind'     => { 'diathesis' => 'act', 'tense' => 'sim', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-+ukan-presind'        => { 'diathesis' => 'act', 'tense' => 'sim', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-imp+izan-finpresind'  => { 'diathesis' => 'act', 'tense' => 'sim', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-imp+izan-presind'     => { 'diathesis' => 'act', 'tense' => 'sim', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-imp+ukan-finpresind'  => { 'diathesis' => 'act', 'tense' => 'sim', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-imp+ukan-presind'     => { 'diathesis' => 'act', 'tense' => 'sim', 'deontmod' => 'decl', 'verbmod' => 'ind' },

    ### etortzen zen -> past, progresive?
    'LEX-+izan-finpastind'     => { 'diathesis' => 'act', 'tense' => 'ant', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-+izan-pastind'        => { 'diathesis' => 'act', 'tense' => 'ant', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-+ukan-finpastind'     => { 'diathesis' => 'act', 'tense' => 'ant', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-+ukan-pastind'        => { 'diathesis' => 'act', 'tense' => 'ant', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-imp+izan-finpastind'  => { 'diathesis' => 'act', 'tense' => 'ant', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-imp+izan-pastind'     => { 'diathesis' => 'act', 'tense' => 'ant', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-imp+ukan-finpastind'  => { 'diathesis' => 'act', 'tense' => 'ant', 'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-imp+ukan-pastind'     => { 'diathesis' => 'act', 'tense' => 'ant', 'deontmod' => 'decl', 'verbmod' => 'ind' },

    ### etorri da -> past, perfective
    'LEX-perf+izan-finpresind'  => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'decl', 'verbmod' => 'ind', 'aspect' => 'cpl' },
    'LEX-perf+izan-presind'     => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'decl', 'verbmod' => 'ind', 'aspect' => 'cpl' },
    'LEX-perf+ukan-finpresind'  => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'decl', 'verbmod' => 'ind', 'aspect' => 'cpl' },
    'LEX-perf+ukan-presind'     => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'decl', 'verbmod' => 'ind', 'aspect' => 'cpl' },

    ### etorri zen -> past
    'LEX-perf+izan-finpastind'  => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-perf+izan-pastind'     => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-perf+ukan-finpastind'  => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-perf+ukan-pastind'     => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'decl', 'verbmod' => 'ind' },

    ### etorri zitekeen -> past
    'LEX-perf+ezan-'            => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'poss', 'verbmod' => 'ind' },
    'LEX-+ezan-'                => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'poss', 'verbmod' => 'ind' },
    'LEX-perf+edin-'            => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'poss', 'verbmod' => 'ind' },
    'LEX-+edin-'                => { 'diathesis' => 'act', 'tense' => 'ant',  'deontmod' => 'poss', 'verbmod' => 'ind' },

    ### etorriko da -> future
    'LEX-pro+izan-finpresind'      => { 'diathesis' => 'act', 'tense' => 'post',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-pro+izan-presind'         => { 'diathesis' => 'act', 'tense' => 'post',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-pro+ukan-finpresind'      => { 'diathesis' => 'act', 'tense' => 'post',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-pro+ukan-presind'         => { 'diathesis' => 'act', 'tense' => 'post',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-part+izan-presind'        => { 'diathesis' => 'act', 'tense' => 'post',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-part+izan-finpresind'     => { 'diathesis' => 'act', 'tense' => 'post',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-part+ukan-finpresind'     => { 'diathesis' => 'act', 'tense' => 'post',  'deontmod' => 'decl', 'verbmod' => 'ind' },
    'LEX-part+ukan-presind'        => { 'diathesis' => 'act', 'tense' => 'post',  'deontmod' => 'decl', 'verbmod' => 'ind' },

    ### etorriko zen -> conditional
    'LEX-pro+izan-pastind'         => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'cdn' },
    'LEX-pro+izan-finpastind'      => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'cdn' },
    'LEX-pro+ukan-pastind'         => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'cdn' },
    'LEX-pro+ukan-finpastind'      => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'cdn' },
    'LEX-part+izan-pastind'        => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'cdn' },
    'LEX-part+izan-finpastind'     => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'cdn' },
    'LEX-part+ukan-pastind'        => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'cdn' },
    'LEX-part+ukan-finpastind'     => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'cdn' },

    ### etorriko litzateke -> conditional
    'LEX-pro+izan-prescnd'      => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'cdn' },
    'LEX-pro+ukan-prescnd'      => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'cdn' },
    'LEX-part+izan-prescnd'     => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'cdn' },
    'LEX-part+ukan-prescnd'     => { 'diathesis' => 'act', 'tense' => 'sim',  'deontmod' => 'decl', 'verbmod' => 'cdn' },
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
    return $anode->get_iset('verbform') . $anode->get_iset('tense') . $anode->get_iset('mood') . $anode->get_iset('aspect');
}

# returns de-lexicalized signature of all verb forms in the verbal group (to be mapped to grammatemes)
sub get_verbal_group_signature {
    my ( $self, $tnode, $lex_anode ) = @_;
    my @sig = ();
    foreach my $anode ( grep { $_->is_verb } $tnode->get_anodes( { ordered => 1 } ) ) {

        # de-lexicalize
        my $lemma = $anode == $lex_anode ? 'LEX' : $anode->lemma;

        # put lexical verb first at all times (handle word order change in some embedded clauses)
        if ( $anode == $lex_anode ) {
            unshift @sig, $lemma . '-' . $self->get_form_signature($anode);
        }
        elsif ($anode->lemma !~ /^(ba|al)$/) {
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

Treex::Block::A2T::EU::SetGrammatemes

=head1 DESCRIPTION

Spanish-specific settings for grammatemes values.

Currently, verbal grammatemes are set according to the shape of the verbal group.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
