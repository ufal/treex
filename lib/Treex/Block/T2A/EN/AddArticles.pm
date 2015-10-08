package Treex::Block::T2A::EN::AddArticles;

use Moose;
use Treex::Core::Common;

extends 'Treex::Block::T2A::AddArticles';

override '_build_article_form' => sub {
    return {
        'definite S'   => 'the',
        'definite P'   => 'the',
        'indefinite S' => 'a',
        'indefinite P' => '',
    };
};

override '_get_article_key' => sub {
    my ( $self, $anode, $definiteness ) = @_;

    my $number = ( $anode->morphcat_number || '.' ) ne '.' ? $anode->morphcat_number : 'S';
    return "$definiteness $number";
};

my $PRONOUN = qr{
    \#PersPron|
    th(is|[oe]se|at)|
    wh(at|ich|o(m|se)?)(ever)?|
    (any|every|some|no)(body|one|thing)|each|n?either|(no[_ ])?one|
    both|many|several|
    all|any|most|none|some
}xi;

override 'can_have_article' => sub {
    my ( $self, $tnode, $anode ) = @_;

    # no articles possible/needed for indefinite pronouns
    return 0 if ( $tnode->t_lemma =~ /^($PRONOUN)$/ );
    return 1;
};

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::T2A::EN::AddArticles

=head1 DESCRIPTION

Add a-nodes corresponding to English noun articles, according to the 'definiteness' grammateme.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
