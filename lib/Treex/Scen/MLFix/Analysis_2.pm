package Treex::Scen::MLFix::Analysis_2;

use Moose;
use Treex::Core::Common;
with 'Treex::Core::RememberArgs';

has language => (
	is			=> 'ro',
	isa			=> 'Treex::Type::LangCode',
	required	=> 1
);

has src_language => (
	is			=> 'ro',
	isa			=> 'Str',
	default		=> ''
);

has selector => (
	is			=> 'ro',
	isa			=> 'Treex::Type::Selector',
	default		=> ''
);

has parser => (
	is			=> 'ro',
	isa			=> 'Str',
	default		=> ''
);

has model => (
	is			=> 'ro',
	isa			=> 'Str',
	default		=> ''
);


my %parser_blocks = (
	'mst'		=> 'ParseMST',
);

sub BUILD {
	my ($self) = @_;

	return;
}

sub get_scenario_string {
	my ($self) = @_;

	my $lang = uc($self->language);
	my $language = $self->language;
	my $src_language = $self->src_language;
	my $selector = $self->selector;
	my $parser_block = $parser_blocks{$self->parser};
	my $model_opt = "";
	$model_opt = "model=" . $self->model if $self->model ne "";

	my $scen = "Util::SetGlobal language=$language selector=$selector";

	if($language eq "en" && $parser_block) {
		$scen = join "\n", $scen,
		"W2A::${lang}::$parser_block $model_opt",
		"W2A::${lang}::SetIsMemberFromDeprel",
		"W2A::${lang}::RehangConllToPdtStyle",
		"W2A::${lang}::FixNominalGroups",
		"W2A::${lang}::FixIsMember",
		"W2A::${lang}::FixAtree",
		"W2A::${lang}::FixMultiwordPrepAndConj",
		"W2A::${lang}::FixDicendiVerbs",
		"W2A::${lang}::SetAfunAuxCPCoord",
		"W2A::${lang}::SetAfun";
	}
    # use depfix' parser (CS only)
    elsif ($language eq "cs" && $self->parser eq "mst_boost") {
        $scen = join "\n", $scen,
        "W2A::CS::ParseMSTperl model_na1me=boost_model_025 use_aligned_tree=1 alignment_language=en alignment_type=intersection alignment_is_backwards=1",
        "W2A::CS::LabelMIRA model_name=pcedt_wors_para use_aligned_tree=1 alignment_language=en alignment_type=intersection alignment_is_backwards=1",
        "A2A::GuessIsMember";
    }
    # use depfix' default parser (CS only)
	elsif ($language eq "cs" && $self->parser eq "mst_default") {
		$scen = join "\n", $scen,
        "W2A::CS::ParseMSTAdapted",
        "W2A::CS::FixAtreeAfterMcD",
        "W2A::CS::FixIsMember";
	}
	# Default: try to project src tree structure if no parser is provided
	elsif ($src_language ne "") {
		$scen = join "\n", $scen,
		"A2A::ProjectTreeThroughAlignment language=$src_language to_language=$language to_selector=";
	}

	return $scen;
}

1;


__END__

=encoding utf-8

=head1 NAME

Treex::Scen::Analysis_2 - Provide analytical layer analysis for MLFix

=head1 DESCRIPTION

#TODO

=head1 PARAMETERS

=head1 AUTHORS

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
