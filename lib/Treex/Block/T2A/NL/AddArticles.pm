package Treex::Block::T2A::NL::AddArticles;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::T2A::AddArticles';

override '_build_article_form' => sub {
    return {
        'definite masc sing'   => 'de',
        'definite masc plur'   => 'de',
        'definite fem sing'    => 'de',
        'definite fem plur'    => 'de',
        'definite com sing'    => 'de',
        'definite com plur'    => 'de',
        'definite neut sing'   => 'het',
        'definite neut plur'   => 'de',
        'definite  plur'       => 'de',    # gender is actually irrelevant in plural
        'indefinite masc sing' => 'een',
        'indefinite masc plur' => '',
        'indefinite fem sing'  => 'een',
        'indefinite fem plur'  => '',
        'indefinite com sing'  => 'een',
        'indefinite com plur'  => '',
        'indefinite neut sing' => 'een',
        'indefinite neut plur' => '',
    };
};

override 'can_have_article' => sub {
    my ( $self, $tnode, $anode ) = @_;

    # no articles possible/needed for geen, enig and alike
    return 0 if ( $anode->is_pronoun and ( $tnode->gram_definiteness // '' ) eq 'indefinite' );
    return 1;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::NL::AddArticles

=head1 DESCRIPTION

Add a-nodes corresponding to Dutch noun articles, according to the 'definiteness' grammateme.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
