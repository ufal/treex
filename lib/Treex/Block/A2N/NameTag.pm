package Treex::Block::A2N::NameTag;
use Moose;
use Treex::Core::Common;
use Treex::Tool::NER::NameTag;
extends 'Treex::Block::A2N::BaseNER';

sub _build_ner {
    my ($self) = @_;
    $self->_args->{model} = $self->model;
    return Treex::Tool::NER::NameTag->new($self->_args);
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2N::NameTag

=head1 DESCRIPTION

Apply named entity recognizer NameTag
by Milan Straka and Jana Straková.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
