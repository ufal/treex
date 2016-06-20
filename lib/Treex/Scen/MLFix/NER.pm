package Treex::Scen::MLFix::NER;

use Moose;
use Treex::Core::Common;
with 'Treex::Core::RememberArgs';

has language => (
	is			=> 'ro',
	isa			=> 'Treex::Type::LangCode',
	required	=> 1
);

has model => (
	is			=> 'ro',
	isa			=> 'Str',
	default		=> ''
);

sub BUILD {
	my ($self) = @_;

	return;
}

sub get_scenario_string {
	my ($self) = @_;

	my $language = $self->language;
	my $model = $self->model;

	my $scen = "Util::SetGlobal language=$language";

	if ($language eq "en") {
		$scen = join "\n", $scen,
		"A2N::EN::StanfordNamedEntities model=$model",
		"A2N::EN::DistinguishPersonalNames";
	}
	elsif ($language eq "cs") {
		$scen = join "\n", $scen,
		"A2N::CS::SimpleRuleNER";
	}

	return $scen;
}

1;


__END__

=encoding utf-8

=head1 NAME

Treex::Scen::MLFix::NER - NER scenario for MLFix pipeline

=head1 DESCRIPTION

#TODO

=head1 PARAMETERS

=head1 AUTHORS

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
