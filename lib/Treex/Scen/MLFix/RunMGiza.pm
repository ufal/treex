package Treex::Scen::MLFix::RunMGiza;

use Moose;
use Treex::Core::Common;
with 'Treex::Core::RememberArgs';

has from_language => (
	is			=> 'ro',
	isa			=> 'Treex::Type::LangCode',
	required	=> 1
);

has to_language => (
	is			=> 'ro',
	isa			=> 'Treex::Type::LangCode',
	required	=> 1
);

has selector => (
	is			=> 'ro',
	isa			=> 'Treex::Type::Selector',
	default		=> ''
);

has dir_or_sym => (
	is			=> 'ro',
	isa			=> 'Str',
	default		=> 'intersection'
);

has model => (
	is			=> 'ro',
	isa			=> 'Str',
	required	=> 1
);

has tmp_dir => (
	is			=> 'ro',
	isa			=> 'Str',
	default		=> '/tmp'
);

has cpu_cores => (
	is          => 'ro',
	isa         => 'Num',
	default		=> 1
);

sub BUILD {
	my ($self) = @_;

	return;
}

sub get_scenario_string {
	my ($self) = @_;

	my $from_language = $self->from_language;
	my $to_language = $self->to_language;
	my $selector = $self->selector;
	my $dir_or_sym = $self->dir_or_sym;
	my $model = $self->model;
	my $tmp_dir = $self->tmp_dir;
	my $cpu_cores = $self->cpu_cores;

	my $scen = join "\n",
	"Align::A::AlignMGiza dir_or_sym=$dir_or_sym selector=$selector from_language=$from_language to_language=$to_language model_from_share=$model tmp_dir=$tmp_dir cpu_cores=$cpu_cores",
	"Align::AddMissingLinks layer=a selector=$selector language=$from_language target_language=$to_language alignment_type=$dir_or_sym",
	"Align::ReverseAlignment language=$from_language selector=$selector";

	return $scen;
}

1;


__END__

=encoding utf-8

=head1 NAME

Treex::Scen::MLFix::RunMGiza - Create alignment and reverse alignment between two languages

=head1 DESCRIPTION

#TODO

=head1 PARAMETERS

=head1 AUTHORS

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
