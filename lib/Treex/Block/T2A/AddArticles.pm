package Treex::Block::T2A::AddArticles;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'article_form' => ( isa => 'HashRef', is => 'ro', lazy_build => 1, builder => '_build_article_form' );

# To be overridden for each language
sub _build_article_form { return {} }

# Getting article key (that will identify it in the article_form table)
sub _get_article_key {
    my ( $self, $anode, $definiteness ) = @_;

    my $gender = $anode->iset->gender // '';
    my $number = $anode->iset->number // '';
    return "$definiteness $gender $number";
}

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $anode = $tnode->get_lex_anode()   or return;
    my $def   = $tnode->gram_definiteness or return;

    return if ( not $self->can_have_article( $tnode, $anode ) );

    my $form = $self->article_form->{ $self->_get_article_key( $anode, $def ) } or return;

    my $article = $anode->create_child(
        {
            'lemma' => $form,
            'form'  => $form,
            'afun'  => 'AuxA',
        }
    );
    my $iset_def = $def eq 'definite' ? 'def' : 'ind';
    $article->iset->add( pos => 'adj', prontype => 'art', definiteness => $iset_def );
    $article->shift_before_subtree($anode);
    $tnode->add_aux_anodes($article);
    return;
}

# To be overridden for each language
sub can_have_article {
    return 1;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::AddArticles

=head1 DESCRIPTION

Add a-nodes corresponding to articles of nouns according to the 'definiteness' grammateme.

This block only contains a generic procedure, article forms must be defined for each
language.

=head1 AUTHORS 

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
