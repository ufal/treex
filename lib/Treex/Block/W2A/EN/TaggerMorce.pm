package Treex::Block::W2A::EN::TaggerMorce;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

has '+language' => (default => 'en');
has _tagger     => (is => 'rw'); 

use Morce::English;
use DowngradeUTF8forISO2;

sub BUILD {
    my ($self) = @_;

    $self->_set_tagger(Morce::English->new());
    
    return;
}

sub process_zone {
    my ( $self, $zone ) = @_;

    my $a_root = $zone->get_a_tree();
    my @forms = map { DowngradeUTF8forISO2::downgrade_utf8_for_iso2($_->form) } $a_root->get_descendants();
  
    # get tags
    my ($tags_rf) = $self->_tagger->tag_sentence( \@forms );
    if ( @$tags_rf != @forms ) {
        log_fatal "Different number of tokens and tags. TOKENS: @forms, TAGS: " . @$tags_rf;
    }

    # fill tags
    foreach my $a_node ($a_root->get_descendants) {
        $a_node->set_tag(shift @$tags_rf);
    }

    return 1;
}

1;


__END__

=pod

=over

=item Treex::Block::W2A::EN::TaggerMorce

Each node in analytical tree is tagged using C<Morce::English> (Penn Treebank POS tags).
This block does NOT do lemmatization.

=back

=cut

# Copyright 2011 David Marecek
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
