package Treex::Block::T2A::ES::AddArticles;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %formOfArticle = (
    'definite masc sing' => 'el',
    'definite masc plu' => 'los',
    'definite fem sing' => 'la',
    'definite fem plu' => 'las',
    'indefinite masc sing' => 'un',
    'indefinite masc plu' => 'unos',
    'indefinite fem sing' => 'una',
    'indefinite fem plu' => 'unas',
);

sub process_tnode {
    my ( $self, $tnode ) = @_;
    my $anode  = $tnode->get_lex_anode() or return;
    my $def    = $tnode->gram_definiteness or return;
    my $gender = $anode->iset->gender;
    my $number = $anode->iset->number;
    my $form   = $formOfArticle{"$def $gender $number"} or return;
 
    my $article = $anode->create_child({
        'lemma'        => $form,
        'form'         => $form,
        'afun'         => 'AuxA',
    });
    my $iset_def = $def eq 'definite' ? 'def' : 'ind';
    $article->iset->add(pos=>'adj', adjtype=>'art', definiteness=> $iset_def );
    $article->shift_before_subtree($anode);
    $tnode->add_aux_anodes($article);
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::AddArticles

=head1 DESCRIPTION

Add a-nodes corresponding to articles of nouns.

Using several heuristic rules to determine the article.

=head1 AUTHORS 

Jan Ptáček

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
