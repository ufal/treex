package Treex::Block::W2A::TagTnT;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Tagger::TnT;
extends 'Treex::Block::W2A::Tag';

has 'model' => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1
);

has 'known_models' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {{
        'hi' => "data/models/tagger/tnt/hindi",
    }},
);

has 'using_lang_model' => (
    is => 'ro',
    isa => 'Str',
    lazy_build => 1
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
    return Treex::Tool::Tagger::TnT->new($self->_args);
}

1;


__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::TagTnT

=head1 DESCRIPTION

This block loads L<Treex::Tool::Tagger::TnT> (a wrapper for the TnT tagger) with
the given C<model>,  feeds it with all the input tokenized sentences, and fills the C<tag>
parameter of all a-nodes with the tagger output.

=head1 PARAMETERS

=over

=item C<model>

The path to the tagger model within the shared directory. This parameter is required if C<using_lang_model>
is not supplied.

=item C<using_lang_model>

The 2-letter language code of the POS model to be loaded. The C<model> parameter can be omitted if this
parameter is supplied. Currently, the models are available for the following
languages,


=over 3

=item - 'hi'.

=back

=back

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>
Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>
Ales Tamchyna <tamchyna@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
