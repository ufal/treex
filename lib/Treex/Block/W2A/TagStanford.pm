package Treex::Block::W2A::TagStanford;
use Moose;
use Treex::Core::Common;
use Treex::Core::Config;
use Treex::Tool::Tagger::Stanford;
use Treex::Tool::Tagger::Service;

extends 'Treex::Block::W2A::Tag';

has 'model' => (
	is => 'ro',
	isa => 'Str',
    predicate => 'has_model'
);

has 'known_models' => (
	is        => 'rw',
	isa       => 'HashRef',
	default	=> sub {{
      	'bn'	=> "data/models/tagger/stanford/bengali-icon10-pdtstyle.model",
      	'cs'	=> "data/models/tagger/stanford/czech-conll2007.model",
      	'de'	=> "data/models/tagger/stanford/german-fast.tagger",
      	'en'	=> "data/models/tagger/stanford/english-left3words-distsim.tagger",
      	'fr'	=> "data/models/tagger/stanford/french.tagger",
      	'hi'	=> "data/models/tagger/stanford/hindi-icon10-pdtstyle.model",
      	'mr'	=> "data/models/tagger/stanford/marathi-kumaran.model",
      	'ta'	=> "data/models/tagger/stanford/tamil-TamilTB-pdtstyle.model",
      	'te'	=> "data/models/tagger/stanford/telugu-icon10-pdtstyle.model",
  	}}
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
    return Treex::Core::Config->use_services ?
      Treex::Tool::Tagger::Service->new(tagger_name => 'Stanford', %{$self->_args}) :
      Treex::Tool::Tagger::Stanford->new($self->_args);
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Block::W2A::TagStanford

=head1 DESCRIPTION

This block loads L<Treex::Tool::Tagger::Stanford> (a wrapper for the Stanford tagger) with
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

=item - 'bn', 'cs', 'hi', 'mr', 'ta' and 'te'.

=item - 'de', 'en' and 'fr' (Comes with the Stanford tagger)

=back


=back

=head1 SEE ALSO

L<Treex::Block::W2A::EN::TagStanford>, L<Treex::Block::W2A::DE::TagStanford>, L<Treex::Block::W2A::FR::TagStanford>

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>
Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012, 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
