package Treex::Block::A2P::NL::ParseAlpino;

use Moose;
use Treex::Core::Common;
use Treex::Tool::PhraseParser::Alpino;

extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

has _parser => ( is => 'rw' );

sub BUILD {
    my ($self) = @_;
    $self->_set_parser( Treex::Tool::PhraseParser::Alpino->new() );
    return;
}

sub process_document {

    my ( $self, $document ) = @_;
    my @zones = map { $_->get_zone( $self->language, $self->selector ) } $document->get_bundles;
    $self->_parser->parse_zones( \@zones );
}

1;

