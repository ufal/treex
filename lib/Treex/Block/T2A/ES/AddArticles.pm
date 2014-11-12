package Treex::Block::T2A::ES::AddArticles;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::T2A::AddArticles';

override '_build_article_form' => sub {
    return {
        'definite masc sing' => 'el',
        'definite masc plur' => 'los',
        'definite fem sing' => 'la',
        'definite fem plur' => 'las',
        'indefinite masc sing' => 'un',
        'indefinite masc plur' => 'unos',
        'indefinite fem sing' => 'una',
        'indefinite fem plur' => 'unas',
    };
};


1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::ES::AddArticles

=head1 DESCRIPTION

Add a-nodes corresponding to Spanish noun articles, according to the 'definiteness' grammateme.

=head1 AUTHORS 

Martin Popel <popel@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
