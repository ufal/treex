package Treex::Block::W2A::TaggerTreeTagger;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );
has model => ( isa => 'Str', is => 'rw' );
has _tagger => ( is => 'rw' );

use Treex::Tools::Tagger::TreeTagger;

sub BUILD {
    my ($self) = @_;

    # if the model is not specified, check whether there is a default model for given language
    if ( !$self->model ) {
        $self->set_model( $self->require_file_from_share( "data/models/tree_tagger/" . $self->language . ".par" ) );
    }

    $self->_set_tagger( Treex::Tools::Tagger::TreeTagger->new( { model => $self->{model} } ) );
    return;
}

sub process_atree {
    my ( $self, $atree ) = @_;

    my @forms = map { $_->form } $atree->get_descendants();
    my ( $tags, $lemmas ) = @{ $self->_tagger->analyze( \@forms ) };

    # fill tags and lemmas
    foreach my $a_node ( $atree->get_descendants() ) {
        $a_node->set_tag( shift @$tags );
        $a_node->set_lemma( shift @$lemmas );
    }

    return 1;
}

1;

__END__

=pod

=over

=item Treex::Block::W2A::TaggerTreeTageer

=back

=cut

# Copyright 2010-2011 David Marecek, Martin Popel
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
