package Treex::Scen::MLFix::FixPrepare;

use Moose;
use Treex::Core::Common;
with 'Treex::Core::RememberArgs';

has src_language => (
	is			=> 'ro',
	isa			=> 'Treex::Type::LangCode',
	required	=> 1
);


has tgt_language => (
    is          => 'ro',
    isa         => 'Treex::Type::LangCode',
    required    => 1
);  

sub BUILD {
	my ($self) = @_;

	return;
}

sub get_scenario_string {
	my ($self) = @_;

	my $src_language = $self->src_language;
    my $tgt_language = $self->tgt_language;

	my $scen = join "\n",
	"Util::Eval language=$tgt_language selector=T zone=". q('$zone->remove_tree("a") if $zone->has_tree("a");'),
	"Util::Eval language=$tgt_language selector=FIXLOG zone=".q('$zone->set_sentence("");'),
	"A2A::CopyAtree source_language=$tgt_language language=$tgt_language selector=T align=1",
    #"Align::AlignSameSentence language=$tgt_language to_selector=T",
	"Align::AlignForward language=$tgt_language selector=T overwrite=0 preserve_type=0";

	return $scen;
}

1;


__END__

=encoding utf-8

=head1 NAME

Treex::Scen::FixPrepare - Prepare analyzed MT output for MLFix application

=head1 DESCRIPTION

#TODO

=head1 PARAMETERS

=head1 AUTHORS

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
