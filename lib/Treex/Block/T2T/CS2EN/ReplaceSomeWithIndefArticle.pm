package Treex::Block::T2T::CS2EN::ReplaceSomeWithIndefArticle;

use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::EN::Countability;

extends 'Treex::Core::Block';

sub process_tnode {
    my ( $self, $tnode ) = @_;

    my $lemma  = $tnode->t_lemma     // '';
    my $countability = Treex::Tool::Lexicon::EN::Countability::countability($lemma);

    $self->replace_some_with_indef($tnode, $countability);
}

sub replace_some_with_indef {
    my ( $self, $tnode, $countability ) = @_;

    return 0 if ( $countability && $countability ne 'countable' );
    return 0 if ( !defined $tnode->gram_number || $tnode->gram_number ne 'sg' );
    my ($some_tnode) = grep { $_->t_lemma eq 'some' } $tnode->get_children;
    return 0 if ( !defined $some_tnode );

    $some_tnode->remove( { children => 'rehang' } );
    $tnode->set_gram_definiteness('indefinite');
    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::CS2EN::ReplaceSomeWithIndefArticle

=head1 DESCRIPTION

The word "some" resulting from translation of "nějaký" in Czech is replaced with an indication of 
indefiniteness (that will turn into an indefinite article).

The replacement is applied in countable singular nouns, where "some" is not appropriate but
the indefinite article is appropriate.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
