package Treex::Scen::MLFix::Fix;

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
	required	=> 1
);

has mark_config_file => (
	is			=> 'ro',
	isa			=> 'Str',
	required	=> 1
);

has fix_config_file => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1
);

has iset_driver	=> (
	is			=> 'ro',
	isa			=> 'Str',
	required	=> 1
);

has mark_method => (
    is          => 'ro',
    isa         => 'Str',
    default     => 'scikit-learn'
);

has fix_method => (
    is          => 'ro',
    isa         => 'Str',
    default     => 'scikit-learn'
);

my %mark_blocks = (
    'scikit-learn'  => 'MarkByScikitLearn',
    'oracle'        => 'MarkByOracle',
);

my %fix_blocks = (
    'scikit-learn'  => 'ScikitLearn',
    'oracle'        => 'Oracle'
);


sub BUILD {
	my ($self) = @_;

	return;
}

sub get_scenario_string {
	my ($self) = @_;

	my $lang = uc($self->language);
    my $markBlock = $mark_blocks{$self->mark_method};
    my $fixBlock = $fix_blocks{$self->fix_method};

    my $scen = "";
    if ($self->mark_method eq "oracle") {
        $scen = "MLFix::${markBlock} language=".$self->language." selector=".$self->selector." config_file=".$self->mark_config_file;
    }
    else {
        $scen = "MLFix::${lang}::${markBlock} language=".$self->language." selector=".$self->selector." config_file=".$self->mark_config_file;
    }

	$scen = join "\n",
    $scen,
	"MLFix::${lang}::${fixBlock} language=".$self->language." selector=".$self->selector." config_file=".$self->fix_config_file." iset_driver=".$self->iset_driver;

	return $scen;
}

1;


__END__

=encoding utf-8

=head1 NAME

Treex::Scen::Fix - Call correct MLFix Fix block for the language

=head1 DESCRIPTION

#TODO

=head1 PARAMETERS

=head1 AUTHORS

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
