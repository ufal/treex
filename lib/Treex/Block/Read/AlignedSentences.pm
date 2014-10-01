package Treex::Block::Read::AlignedSentences;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseAlignedTextReader';

sub next_document {
    my ($self) = @_;

    my $texts_ref = $self->next_document_texts();

    return if !defined $texts_ref;

    my %sentences =
        map { $_ => [ split /\n/, $texts_ref->{$_} ] } keys %{$texts_ref};

    my $n = 0;
    for my $zone_label ( keys %sentences ) {
        if ( !$n ) {
            $n = @{ $sentences{$zone_label} };
        }
        log_fatal "Different number of lines in aligned documents"
            if $n != @{ $sentences{$zone_label} };
    }

    my $doc = $self->new_document();
    for my $i ( 0 .. $n - 1 ) {
        my $bundle = $doc->create_bundle();
        for my $zone_label ( keys %sentences ) {
            my ( $lang, $selector ) = ( $zone_label, $self->selector );
            if ( $zone_label =~ /_/ ) {
                ( $lang, $selector ) = split /_/, $zone_label;
            }
            my $zone = $bundle->create_zone( $lang, $selector );
            $zone->set_sentence( $sentences{$zone_label}[$i] );
        }
    }

    return $doc;
}

1;

__END__


=head1 NAME

Treex::Block::Read::AlignedSentences

=head1 SYNOPSIS

  # in scenarios
  # Read::AlignedSentences en=en1.txt,en2.txt cs_ref=cs1.txt,cs2.txt

=head1 DESCRIPTION

Document reader for plain text format, one sentence per line.
Aligned sentences (usually in different languages) are loaded at once into respective zones.
The sentences are stored into L<bundles|Treex::Core::Bundle> in the
L<document|Treex::Core::Document>.

=head1 ATTRIBUTES

=over

=item any parameter in a form of a valid I<zone_label>

space or comma separated list of filenames, or C<-> for STDIN.

=back

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 SEE ALSO

L<Treex::Block::Read::BaseAlignedReader>
L<Treex::Block::Read::BaseAlignedTextReader>
L<Treex::Core::Document>
L<Treex::Core::Bundle>

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
