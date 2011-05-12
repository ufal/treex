package Treex::Block::A2P::ParseCharniak;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

has _parser     => ( is       => 'rw', required => 1, default => 'en');

use Treex::Tools::PhraseParser::Charniak;

sub BUILD {
    my ($self) = @_;
    $self->_set_parser( Treex::Tools::PhraseParser::Charniak->new( { language => $self->language } ) );
    return;
}

sub process_document {
    my ( $self, $document ) = @_;

    my $arg_ref = {language=>$self->language};
    if ($self->selector) {
        $arg_ref->{selector} = $self->selector;
    }


    my @zones =  map { $_->get_zone('en','src')} $document->get_bundles;
    $self->_parser->parse_zones(\@zones);

}


1;

=pod

=over

=item Treex::Block::A2P::ParseStanford

Expects tokenized nodes (a-tree),
creates phrase-structure trees using Stanford constituency parser.
(not in ::EN:: in hope that there will be models for more languages)

=back

=cut

# Copyright 2011 Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.





