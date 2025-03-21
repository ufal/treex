package Treex::Block::A2A::CorefDestroyWild;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



sub process_document
{
    my $self = shift;
    my $document = shift;
    delete($document->wild()->{eset});
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CorefDestroyWild

=item DESCRIPTION

CorefUD-related blocks such as A2A::CorefClusters and A2A::CorefMentions create
and manipulate a Treex::Core::EntitySet object, which is stored as a wild
attribute of the document. When no longer needed, it should be destroyed by
placing this block in the scenario. We cannot leave the EntitySet object among
the wild attributes of the document. The Treex writer would attempt to
serialize it to the output and it would fail because of cyclic references.

=head1 AUTHORS

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2025 by Institute of Formal and Applied Linguistics, Charles University, Prague.

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
