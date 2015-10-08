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

override 'can_have_article' => sub {
    my ( $self, $tnode, $anode ) = @_;

    # no articles possible/needed for indefinite pronouns
    return 0 if ( $anode->is_pronoun and ( $tnode->gram_definiteness // '' ) eq 'indefinite' );
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
