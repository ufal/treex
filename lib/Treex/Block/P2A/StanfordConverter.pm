package Treex::Block::P2A::StanfordConverter;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';
use Treex::Tool::Phrase2Dep::StanfordConverter;

has '+language' => ( required => 1 );

has _converter => ( is => 'rw', required => 1, default => 'en' );

sub BUILD {
    my ($self) = @_;
    $self->_set_converter( Treex::Tool::Phrase2Dep::StanfordConverter->new( { language => $self->language } ) );
    return;
}

sub process_document {
    my ( $self, $document ) = @_;
    my @zones = map { $_->get_zone( $self->language, $self->selector ) } $document->get_bundles;
    $self->_converter->convert_zones( \@zones );

}


1;



=over

=item Treex::Block::P2A::StanfordConverter

Expects phrase structure (p-tree),
creates dependency structure (a-tree) using basic Stanford Dependencies

=back

=cut

# Copyright 2011 Lenka Smejkalova <smejkalova@ufal.mff.cuni.cz>

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.

