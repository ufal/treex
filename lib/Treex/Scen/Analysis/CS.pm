package Treex::Scen::Analysis::CS;
use Moose;
use Treex::Core::Common;
with 'Treex::Core::RememberArgs';

sub get_scenario_string {
    my ($self) = @_;
    my $params = $self->args_str;

    my $scen = join "\n",
    "Scen::Analysis::CS::M $params",
    "Scen::Analysis::CS::N $params",
    "Scen::Analysis::CS::A $params",
    "Scen::Analysis::CS::T $params",
    ;

    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Analysis::CS - Czech tectogrammatical analysis

=head1 SYNOPSIS

 # From command line
 treex -Lcs Read::Sentences from=my.txt Scen::Analysis::CS Write::Treex to=my.treex.gz
 
 treex --dump_scenario Scen::Analysis::CS

=head1 DESCRIPTION

This scenario starts with tokenization, so sentence segmentation must be performed before.
It covers: tokenization, tagging+lemmatization (MorphoDiTa), NER (NameTag),
dependency parsing (MST) and tectogrammatical analysis.

Sequentially invokes
L<Scen::Analysis::CS::M>,
L<Scen::Analysis::CS::N>,
L<Scen::Analysis::CS::A>, and
L<Scen::Analysis::CS::T>.

=head1 PARAMETERS

See
L<Scen::Analysis::CS::M>,
L<Scen::Analysis::CS::N>,
L<Scen::Analysis::CS::A>, and
L<Scen::Analysis::CS::T>.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
