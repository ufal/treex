package Treex::Block::Read::CdtTag;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseReader';

use XML::Twig;

sub next_document {
    my ($self) = @_;

    my $filename = $self->next_filename();

    return if not defined $filename;

    my $document = Treex::Core::Document->new;

    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::CdtTag

=head1 DESCRIPTION

Document reader for *.tag files used in the Copenhagen Dependency Treebank
and associated projects. The tag format is a semi-XML line-oriented format.

=head1 AUTHOR

Zdeněk Žabokrtský

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
