package Treex::Block::Read::CETLEF;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseReader';
use XML::Simple;

has bundles_per_doc => (
    is      => 'ro',
    isa     => 'Int',
    default => 0,
);

has cs_selector => ( isa => 'Treex::Type::Selector', is => 'ro', default => '' );
has fr_selector => ( isa => 'Treex::Type::Selector', is => 'ro', default => '' );

has _buffer => ( is => 'rw', default => sub { [] } );

sub BUILD {
    my ($self) = @_;
    if ( $self->bundles_per_doc ) {
        $self->set_is_one_doc_per_file(0);
    }
    return;
}

sub next_document {
    my ($self) = @_;
    if ( !@{ $self->_buffer } ) {
        my $filename = $self->next_filename();
        return if !defined $filename;
        log_info "Loading $filename...";
        my $xml_doc = XMLin( $filename );
        $self->_set_buffer( $xml_doc->{ph} );
    }

    my $document = $self->new_document();
    my $sent_num = 0;
    while ( @{ $self->_buffer } ) {
        $sent_num++;
        last if $self->bundles_per_doc && $sent_num > $self->bundles_per_doc;

        my $xml_bundle = shift @{ $self->_buffer };
        my $bundle     = $document->create_bundle();
        $bundle->set_id($xml_bundle->{id_req});
        my $cs_zone    = $bundle->create_zone( 'cs', $self->cs_selector );
        my $fr_zone    = $bundle->create_zone( 'fr', $self->fr_selector );
        $cs_zone->set_sentence($xml_bundle->{cs});
        $fr_zone->set_sentence($xml_bundle->{fr});
    }

    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::CETLEF - load Czech-French parallel sentences from XML

=head1 DESCRIPTION

Document reader for the XML-based CETLEF format
used for storing parallel Czech and French sentences.

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 PARAMETERS

=over

=item bundles_per_doc

Maximum number of bundles for each document
(if the source file contains more sentences, several documents will be created).
Zero means unlimited. 

=item (cs|fr)_selector

What selector to be assigned to the new zones. Default is empty string.

=back

=head1 SEE

L<Treex::Block::Read::BaseReader>

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
