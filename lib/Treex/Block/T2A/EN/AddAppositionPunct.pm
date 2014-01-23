package Treex::Block::T2A::EN::AddAppositionPunct;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddAppositionPunct';

use Treex::Tool::Lexicon::EN::Hypernyms;

override 'is_apposition' => sub {
    my ( $self, $tnode, $parent ) = @_;

    # ruling out the obvious
    return 0 if ( $tnode->formeme ne 'n:attr' or not $parent->precedes($tnode) or $parent->formeme !~ /^n/ );

    if ( ( $tnode->gram_sempos // '' ) eq 'n.denot' ) {

        # rule out D. for "Ph. D."
        return 0 if ( $tnode->t_lemma eq 'D' and $parent->t_lemma eq 'Ph' );

        # rule out brackets
        return 0 if ( $tnode->is_parenthesis );

        # "Seatle, WA"
        return 1 if ( Treex::Tool::Lexicon::EN::Hypernyms::is_country( $tnode->t_lemma ) );

        # Seems like named entities (cities etc.) have capitalized lemmas
        return 1 if ( $tnode->t_lemma eq ucfirst( $tnode->t_lemma ) );

        # "John, my best friend"
        return 1 if ( $tnode->get_children() );

    }
    elsif ( $tnode->t_lemma =~ /^[12][0-9]{3}$/ ) {    # numbers: only years

        # only those hanging under month name
        return 0 if ( $parent->t_lemma !~ /^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)/i );

        # only those that contain day number
        return 1 if ( any { $_->t_lemma =~ /^[123]?[0-9]$/ } $parent->get_children() );
    }
    return 0;
};

1;
__END__


=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::AddAppositionPunct

=head1 DESCRIPTION

Add commas in apposition constructions such as "John, my best friend, ...".

This language-specific module just detects appositions in English, the actual
adding of commas is implemented in L<Treex::Block::T2A::AddAppositionPunct>. 

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
