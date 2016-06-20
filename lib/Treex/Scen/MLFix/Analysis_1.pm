package Treex::Scen::MLFix::Analysis_1;

use Moose;
use Treex::Core::Common;
with 'Treex::Core::RememberArgs';

has language => (
	is			=> 'ro',
	isa			=> 'Treex::Type::LangCode',
	required	=> 1
);

has selector => (
	is			=> 'ro',
	isa			=> 'Treex::Type::Selector',
	default		=> ''
);

has tagger => (
	is			=> 'ro',
	isa			=> 'Str',
	default		=> 'morphodita'
);

has lemmatize => (
	is			=> 'ro',
	isa			=> 'Str',
	default		=> 1
);

has iset_driver	=> (
	is			=> 'ro',
	isa			=> 'Str',
	required	=> 1
);

my %tagger_blocks = (
	'featurama'		=> 'TagFeaturama',
	'morce'			=> 'TagMorce',
	'morphodita'	=> 'TagMorphoDiTa',
	'stanford'		=> 'TagStanford'
);

sub BUILD {
	my ($self) = @_;

	return;
}

sub get_scenario_string {
	my ($self) = @_;

	my $lang = uc($self->language);
	my $language = $self->language;
	my $selector = $self->selector;
	my $tagger_block = $tagger_blocks{$self->tagger};
	my $lemmatize = $self->lemmatize;
	my $iset_driver = $self->iset_driver;

	$lemmatize = 0 if $language eq "en";

	my $scen = join "\n",
	"Util::SetGlobal language=$language selector=$selector",
	"Util::Eval zone=" . q('$zone->remove_tree("a") if $zone->has_tree("a");'),
	"W2A::${lang}::Tokenize",

	$language eq "en" ? "W2A::EN::NormalizeForms" : (),
	$language eq "en" ? "W2A::EN::FixTokenization" : (),

	"W2A::${lang}::$tagger_block lemmatize=$lemmatize",

	$language eq "en" ? "W2A::EN::FixTags" : (),
	$language eq "en" ? "W2A::EN::Lemmatize" : (),

	"A2A::ConvertTags input_driver='$iset_driver'";

	return $scen;
}

1;


__END__

=encoding utf-8

=head1 NAME

Treex::Scen::Analysis_1 - Provide morphological analysis for MLFix

=head1 DESCRIPTION

#TODO

=head1 PARAMETERS

=head1 AUTHORS

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
