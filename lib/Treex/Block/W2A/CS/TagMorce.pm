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

my $max_word_length = 45;

sub process_atree {
    my ( $self, $atree ) = @_;

    my @a_nodes = $atree->get_descendants( { ordered => 1 } );
    my @forms =
      map { substr($_, -$max_word_length, $max_word_length) }
        # avoid words > $max_word_length chars; Morce segfaults, take the suffix
      map { DowngradeUTF8forISO2::downgrade_utf8_for_iso2( $_->form ) }
      @a_nodes;

    # get tags and lemmas
    my ( $tags_rf, $lemmas_rf ) = $self->_tagger->tag_sentence( \@forms );
    if ( @$tags_rf != @forms || @$lemmas_rf != @forms ) {
        log_fatal "Different number of tokens, tags and lemmas. TOKENS: @forms, TAGS: @$tags_rf, LEMMAS: @$lemmas_rf.";
    }

    # fill tags
    foreach my $a_node ( @a_nodes ) {
        $a_node->set_tag( shift @$tags_rf );
        my $gotlemma = shift @$lemmas_rf;
        if (length($gotlemma) == $max_word_length
            && $gotlemma
               eq substr($a_node->form, -$max_word_length, $max_word_length)) {
          # this word was long and artificially truncated, use the full form
          $a_node->set_lemma($a_node->form);
        } else {
          $a_node->set_lemma( $gotlemma );
        }
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
