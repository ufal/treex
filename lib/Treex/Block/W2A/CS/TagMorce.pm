package Treex::Block::W2A::CS::TagMorce;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has _tagger => ( is => 'rw' );

use Morce::Czech;
use DowngradeUTF8forISO2;

sub BUILD {
    my ($self) = @_;

    $self->_set_tagger( Morce::Czech->new() );

    return;
}

sub process_atree {
    my ( $self, $atree ) = @_;

    my @forms = map { DowngradeUTF8forISO2::downgrade_utf8_for_iso2( $_->form ) } $atree->get_descendants( { ordered => 1 } );

    # get tags and lemmas
    my ( $tags_rf, $lemmas_rf ) = $self->_tagger->tag_sentence( \@forms );
    if ( @$tags_rf != @forms || @$lemmas_rf != @forms ) {
        log_fatal "Different number of tokens, tags and lemmas. TOKENS: @forms, TAGS: @$tags_rf, LEMMAS: @$lemmas_rf.";
    }

    # fill tags
    foreach my $a_node ( $atree->get_descendants ) {
        $a_node->set_tag( shift @$tags_rf );
        $a_node->set_lemma( shift @$lemmas_rf );
    }

    return 1;
}

1;

__END__

=pod

=over

=item Treex::Block::W2A::CS::TagMorce

Each node in analytical tree is tagged using C<Morce::Czech> tagger.
Lemmata are also assigned.

=back

=cut

# Copyright 2011 David Marecek
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
