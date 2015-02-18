package Treex::Block::W2A::TagMorphoDiTa;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Tagger::MorphoDiTa;
extends 'Treex::Block::W2A::Tag';

has 'known_models' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {{
        cs => 'data/models/morphodita/cs/czech-morfflex-pdt-131112.tagger-best_accuracy',
        en => 'data/models/morphodita/en/english-morphium-wsj-140407.tagger',
    }},
);

has 'model' => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_model'
);

has 'using_lang_model' => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_using_lang_model'
);

sub _build_tagger {
    my ($self) = @_;
    if ($self->has_model) {
        $self->_args->{model} = $self->model;
    }
    elsif ($self->has_using_lang_model) {
        $self->_args->{model} = $self->known_models()->{$self->using_lang_model};
    }
    else {
        log_fatal('Model path (model=path/to/model) or language (using_lang_model=XX) must be set!');
    }
    return Treex::Tool::Tagger::MorphoDiTa->new($self->_args);
}

after 'process_atree' => sub {
    my ($self, $atree) = @_;
    
    my @nodes = $atree->get_descendants({ordered=>1});

    # It is legal to have a tree with no nodes (e.g. for non 1-1 aligned sentences),
    # so just skip such sentences (and do not log_fatal if no lemmas are found).
    return if !@nodes;

    my $forms_rf = [map { $_->form } @nodes];

    my $guessed = $self->tagger->is_guessed($forms_rf);
    for (my $i = 0; $i < @nodes; $i++) {
        $nodes[$i]->wild->{lemma_guessed} = $guessed->[$i];
    }
};

1;


__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::TagMorphoDiTa

=head1 DESCRIPTION

This block loads L<Treex::Tool::Tagger::MorphoDiTa> (a wrapper for the MorphoDiTa tagger) with
the given C<model>,  feeds it with all the input tokenized sentences, and fills the C<tag>
parameter of all a-nodes with the tagger output.

=head1 PARAMETERS

=head2 C<model>

The path to the tagger model within the shared directory. This parameter is required if C<using_lang_model>
is not supplied.

=head2 C<using_lang_model>

The 2-letter language code of the POS model to be loaded. The C<model> parameter can be omitted if this
parameter is supplied. Currently, the models are available for the following
languages,

=over

=item cs

data/models/morphodita/cs/czech-morfflex-pdt-131112.tagger-best_accuracy

=item en

data/models/morphodita/en/english-morphium-wsj-140407.tagger

=back

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
