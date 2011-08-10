package Treex::Block::W2A::EN::Lemmatize;
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
    my ( $lemma, $neg ) = $self->lemmatizer->lemmatize( $anode->form, $anode->tag );
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

=pod

=over

=item Treex::Block::W2A::EN::Lemmatize

For each node in the analytical tree, attribute C<lemma> is filled with a lemma
derived from attributes C<form> and C<tag> using C<Treex::Tool::EnglishMorpho::Lemmatizer>.

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, David Marecek
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
