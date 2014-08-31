package Treex::Block::W2A::EN::Lemmatize;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::EnglishMorpho::Lemmatizer;

has 'lemmatizer' => (
    is       => 'ro',
    isa      => 'Treex::Tool::EnglishMorpho::Lemmatizer',
    builder  => '_build_lemmatizer',
    init_arg => undef,
    lazy     => 1,
);

sub process_anode {
    my ( $self, $anode ) = @_;
    my ( $lemma ) = $self->lemmatizer->lemmatize( $anode->form, $anode->tag ); #gracefully throwing away second field of returned list
    $anode->set_lemma($lemma);

    return 1;
}

sub _build_lemmatizer {
    my $self       = shift;
    my $lemmatizer = Treex::Tool::EnglishMorpho::Lemmatizer->new();
    return $lemmatizer;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::EN::Lemmatize - wrapper for rule based lemmatizer for English

=head1 DESCRIPTION

For each node in the analytical tree, attribute C<lemma> is filled with a lemma
derived from attributes C<form> and C<tag> using C<Treex::Tool::EnglishMorpho::Lemmatizer>.

=head1 ATTRIBUTES

=over 4

=item lemmatizer

An instance of C<Treex::Tool::EnglishMorpho::Lemmatizer>

=back

=head1 OVERRIDEN METHODS

=head2 from C<Treex::Core::Block>

=over 4

=item process_anode

=back

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008 - 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

