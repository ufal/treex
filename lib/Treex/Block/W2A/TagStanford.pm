package Treex::Block::W2A::TagStanford;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Tagger::Stanford;
extends 'Treex::Block::W2A::Tag';

has 'model' => ( 
	is => 'ro', 
	isa => 'Str', 
	lazy_build => 1 
);

has 'known_models' => (
	is        => 'rw',
	isa       => 'HashRef',
	default	=> sub {{
      	'bn'	=> "installed_tools/tagger/stanford/models/bengali-icon10-pdtstyle.model",
      	'cs'	=> "installed_tools/tagger/stanford/models/czech-conll2007.model",
      	'de'	=> "installed_tools/tagger/stanford/models/german-fast.tagger",
      	'en'	=> "installed_tools/tagger/stanford/models/english-left3words-distsim.tagger",
      	'fr'	=> "installed_tools/tagger/stanford/models/french.tagger",
      	'hi'	=> "installed_tools/tagger/stanford/models/hindi-icon10-pdtstyle.model",
      	'mr'	=> "installed_tools/tagger/stanford/models/marathi-kumaran.model",	
      	'ta'	=> "installed_tools/tagger/stanford/models/tamil-TamilTB-pdtstyle.model",
      	'te'	=> "installed_tools/tagger/stanford/models/telugu-icon10-pdtstyle.model",
  	}}
); 
	
has 'using_lang_model' => (
	is => 'ro',
	isa => 'Str',
	lazy_build => 1
);	


sub _build_tagger{
    my ($self) = @_;
    if ($self->has_model) {
    	$self->_args->{model} = $self->model;
    }
    elsif ($self->has_using_lang_model) {
    	$self->_args->{model} = $self->known_models()->{$self->using_lang_model};
    }
    return Treex::Tool::Tagger::Stanford->new($self->_args);
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

The 2-letter code of the POS model to be loaded. The C<model> parameter can be omitted if this 
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
