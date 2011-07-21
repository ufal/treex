package Treex::Block::A2P::ParseCharniak;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

has _parser     => ( is       => 'rw', required => 1, default => 'en');

use Treex::Tool::PhraseParser::Charniak;

sub BUILD {
    my ($self) = @_;
    $self->_set_parser( Treex::Tool::PhraseParser::Charniak->new( { language => $self->language } ) );
    return;
}

sub process_document {
    my ( $self, $document ) = @_;
    my @zones =  map { $_->get_zone($self->language,$self->selector)} $document->get_bundles;
    $self->_parser->parse_zones(\@zones);
}


1;

=pod

=over

=item Treex::Block::A2P::ParseStanford

Expects tokenized nodes (a-tree),
creates phrase-structure trees using Charniak's constituency parser.

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.





