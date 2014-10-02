package Treex::Block::T2A::NL::AddArticles;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::T2A::AddArticles';

override '_build_article_form' => sub {
    return {
        'definite masc sing' => 'de',
        'definite masc plu' => 'de',
        'definite fem sing' => 'de',
        'definite fem plu' => 'de',
        'definite com sing' => 'de',
        'definite com plu' => 'de',
        'definite neut sing' => 'het',
        'definite neut plu' => 'de',
        'definite  plu' => 'de', # gender is actually irrelevant in plural
        'indefinite masc sing' => 'een',
        'indefinite masc plu' => '',
        'indefinite fem sing' => 'een',
        'indefinite fem plu' => '',
        'indefinite com sing' => 'een',
        'indefinite com plu' => '',
        'indefinite neut sing' => 'een',
        'indefinite neut plu' => '',
    };
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
