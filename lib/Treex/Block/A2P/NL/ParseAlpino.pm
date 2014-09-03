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

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::A2P::NL::Alpino

=head1 DESCRIPTION

Using L<Treex::Tool::PhraseParser::Alpino> to parse Dutch sentences to phrase structure
trees (the input is assumed to be an a-tree, i.e., already tokenized, but no tagging/lemmatization
is needed since this is done by Alpino).

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
