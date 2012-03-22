package Treex::Block::W2A::EN::TagMorce;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has _tagger => ( is => 'rw' );

use Morce::English;
use DowngradeUTF8forISO2;

sub BUILD {
    my ($self) = @_;

    return;
}

sub process_start {
    my ($self) = @_;

    $self->_set_tagger( Morce::English->new() );

    $self->SUPER::process_start();

    return;
}

sub process_atree {
    my ( $self, $atree ) = @_;

    my @a_nodes = $atree->get_descendants( { ordered => 1 } );
    my @forms =
      map { substr($_, -45, 45) } # avoid words > 45 chars; Morce segfaults
      map { DowngradeUTF8forISO2::downgrade_utf8_for_iso2( $_->form ) }
      @a_nodes;

    # get tags
    my ($tags_rf) = $self->_tagger->tag_sentence( \@forms );
    if ( @$tags_rf != @forms ) {
        log_fatal "Different number of tokens and tags. TOKENS: @forms, TAGS: " . @$tags_rf;
    }

    # fill tags
    foreach my $a_node ( @a_nodes ) {
        $a_node->set_tag( shift @$tags_rf );
    }

    return 1;
}

1;

__END__

=pod

=over

=item Treex::Block::W2A::EN::TagMorce

Each node in analytical tree is tagged using C<Morce::English> (Penn Treebank POS tags).
This block does NOT do lemmatization.

=back

=cut

# Copyright 2011 David Marecek
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
