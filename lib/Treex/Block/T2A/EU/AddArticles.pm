package Treex::Block::T2A::EU::AddArticles;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddArticles';

override '_build_article_form' => sub {
    return {
        'indefinite  sing' => 'bat',
        'indefinite  plur' => 'bat',
        'indefinite masc sing' => 'bat',
        'indefinite masc plur' => 'bat',
        'indefinite fem sing' => 'bat',
        'indefinite fem plur' => 'bat',
    };
};

override 'process_tnode' => sub {
    my $self = shift;
    my $tnode = shift;
    my $anode = $tnode->get_lex_anode()   or return;
    my $def   = $tnode->gram_definiteness or return;

    return if ( not $self->can_have_article( $tnode, $anode ) );

    my $gender = $anode->iset->gender // '';
    my $number = $anode->iset->number // '';
    my $form = $self->article_form->{"$def $gender $number"} or return;

    my $article = $anode->create_child(
        {
            'lemma' => $form,
            'form'  => $form,
            'afun'  => 'AuxA',
        }
    );
    my $iset_def = $def eq 'definite' ? 'def' : 'ind';
    $article->iset->add( pos => 'adj', prontype => 'art', definiteness => $iset_def );
    $article->shift_after_subtree($anode);
    $tnode->add_aux_anodes($article);
    return;
};

#artikulua eduki dezakeen edo ez erabakitzen da. sempos n.pron baldin bada edo 'más' bada ezin da.
override 'can_have_article' => sub {
    my ( $self, $tnode , $anode) = @_;

    my @children = $tnode->get_children();
    foreach my $child (@children)
    {
	if (($child->gram_sempos || "") =~ /^n\.pron\./)
	{ return 0; }
    }
    return 1;

};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EU::AddArticles

=head1 DESCRIPTION

Add a-nodes corresponding to Basque noun articles, according to the 'definiteness' grammateme.

=head1 AUTHORS 

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
