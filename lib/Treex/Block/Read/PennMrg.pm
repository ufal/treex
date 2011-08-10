package Treex::Block::Read::PennMrg;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader';

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;
    my $document = $self->new_document();

    foreach my $tree_text ( split /\n\(\s*\(S/ms, $text ) {
        next if $tree_text =~ /^\s*$/;
        my $bundle = $document->create_bundle();
        my $zone   = $bundle->create_zone( $self->language, $self->selector );
        my $proot  = $zone->create_ptree();
        $proot->create_from_mrg("( (S $tree_text");

        #TODO $zone->set_sentence( $sentence );
    }
    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::PennMrg

=head1 DESCRIPTION

Document reader for phrase-structure trees in PennTreeBank C<mrg> format.
The trees are loaded to the p-layer.

=head1 ATTRIBUTES

=over

=item from

space or comma separated list of filenames

=back

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 SEE

L<Treex::Block::Read::BaseTextReader>
L<Treex::Core::Document>
L<Treex::Core::Bundle>

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
