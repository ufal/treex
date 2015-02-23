package Treex::Block::A2N::EN::StanfordNER2008;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::A2N::BaseNER';

# Stanford NER main JAR, path within share
has jar => ( is => 'ro', isa => 'Str', default => 'data/models/stanford_named_ent_recognizer/stanford-ner-2008-05-07/stanford-ner-hacked-STDIN.jar');

has '+model' => ( default => 'data/models/stanford_named_ent_recognizer/stanford-ner-2008-05-07/classifiers/ner-eng-ie.crf-3-all2008.ser.gz' );
#or
#has '+model' => ( default => 'data/models/stanford_named_ent_recognizer/stanford-ner-2008-05-07/classifiers/ner-eng-ie.crf-3-all2008-distsim.ser.gz' );
#but this model is bigger and gets worse results in en2cs TectoMT

use Treex::Tool::NER::Stanford;

sub _build_ner {
    my ($self) = @_;
    $self->_args->{model} = $self->model;
    $self->_args->{jar} = $self->jar;
    return Treex::Tool::NER::Stanford->new($self->_args);
}

1;
__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2N::EN::StanfordNER2008 - Stanford Named Entity recognition

=head1 DESCRIPTION

This block finds I<named entities> with types: person, organization, or location.
The entities are stored in n-trees.

=head1 PARAMETERS

=head2 model

Filename of the model passed to L<NER::Stanford::English>

=head1 SEE ALSO

L<Treex::Tool::NER::Stanford>

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
