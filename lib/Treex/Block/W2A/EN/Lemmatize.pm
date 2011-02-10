package Treex::Block::W2A::EN::Lemmatize;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => ( default => 'en' );

use EnglishMorpho::Lemmatizer;

sub process_anode {
    my ( $self, $anode ) = @_;
    my ( $lemma, $neg ) = EnglishMorpho::Lemmatizer::lemmatize( $anode->form, $anode->tag );
    $anode->set_lemma($lemma);

    return 1;
}

1;

__END__

=pod

=over

=item Treex::Block::W2A::EN::Lemmatize

For each node in the analytical tree, attribute C<lemma> is filled with a lemma
derived from attributes C<form> and C<tag> using C<EnglishMorpho::Lemmatizer>.

=back

=cut

# Copyright 2008-2011 Zdenek Zabokrtsky, David Marecek
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
