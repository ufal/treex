package Treex::Block::Print::Debug::DocumentTextHead;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# We cannot use process_zone() because it works wit bundle zones, not document zones.
# And we are not guaranteed that there are any bundles in the document.
sub process_document
{
    my $self = shift;
    my $document = shift;
    my @zones = $document->get_all_zones();
    foreach my $zone (@zones)
    {
        my $prefix = $zone->language();
        $prefix .= ':'.$zone->selector() if(defined($zone->selector()));
        my $sample = substr($zone->text(), 0, 30);
        $sample =~ s/\r?\n/ /sg;
        my $dots = chr(8230); # \x{2026}
        log_info('DEBUG '.$prefix.':'.$sample.$dots);
    }
}

1;

=head1 NAME

Treex::Block::Print::Debug::DocumentTextHead

=head1 DESCRIPTION

Prints the first few words of the document text.
The document does not need to be segmented into bundles.
Bundles are ignored, only the C<$document-&lt;text> attribute matters.
This way we can debug a document reader and see at which point in time
a new document has been read and subsequent blocks have been applied to it.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
