package Treex::Core::DocZone;

use Moose;

extends 'Treex::Core::Zone';

has text => ( is => 'rw' );

1;

__END__


=encoding utf-8

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

Treex::Core::DocZone instances have the following attributes:

=over 4

=item language

=item selector

=item my $text = $zone->text;

=back

The attributes can be accessed using semi-affordance accessors:
getters have the same names as attributes, while setters start with
'C<set_>'. For example, the attribute C<text> has a getter C<text()> and a setter C<set_text($text)>


=head1 METHODS

=head2 Construction

C<Treex::Core::DocZone> instances should not be created by a constructor,
but should be created exclusively from the embedding document
by one of the document's methods:

=over 4

=item create_zone

=item get_or_create_zone

=back


=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
