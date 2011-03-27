package Treex::Core::DocZone;

use Moose;

extends 'Treex::Core::Zone';

has text => ( is => 'rw' );

1;

__END__


=head1 NAME

Treex::Core::DocZone - document zone for the text attribute

=head1 SYNOPSIS

 use Treex::Core;
 my $doc = Treex::Core->new;
 my $zone = $doc->create_zone('en','reference');
 $zone->set_text('Piece of text. Translated by a human.');


=head1 DESCRIPTION

Document zones allow Treex documents to contain more texts,
typically parallel texts (translations), or corresponding
texts from different sources (text to be translated, reference
translation, test translation).

=head1 ATTRIBUTES

Treex::Core::DocZone has the only attribute C<text> that can
be accessed as follows:

=over 4

=item $zone->set_text($text);

=item my $text = $zone->text;

=back


=head1 AUTHOR

Zdenek Zabokrtsky

=head1 COPYRIGHT AND LICENSE

Copyright 2010-2011 by UFAL

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

