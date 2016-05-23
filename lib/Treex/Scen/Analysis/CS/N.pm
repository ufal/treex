package Treex::Scen::Analysis::CS::N;
use Moose;
use Treex::Core::Common;
use utf8;

has domain => (
     is => 'ro',
     isa => enum( [qw(general IT)] ),
     default => 'general',
     documentation => '',
);

has ner => (
     is => 'ro',
     isa => enum( [qw(NameTag simple none)] ),
     default => 'NameTag',
     documentation => '',
);

sub get_scenario_string {
    my ($self) = @_;

    my $scen = join "\n",
    $self->ner eq 'NameTag' ? 'A2N::CS::NameTag' : (),
    $self->ner eq 'simple' ? 'A2N::CS::SimpleRuleNER' : (),
    $self->domain eq 'IT' ? 'A2N::CS::FixNERforIT' : (),
    'A2N::CS::NormalizeNames',
    ;

    return $scen;
}

1;

=head1 NAME 

Treex::Scen::Analysis::CS::N - Czech analysis from "m-layer" to n-layer

=head1 SYNOPSIS

 treex -Lcs Read::Sentences from=my.txt Scen::Analysis::CS::M Scen::Analysis::CS::N Write::Treex to=my.treex.gz

=head1 DESCRIPTION

Performs named entity recognition (n-layer).

Expects tagged and lemmatized data,
i.e. L<Scen::Analysis::CS::M> is a prerequisite.

=head1 PARAMETERS

=over

=item domain

Domain of the input texts:
C<domain=general> (default),
or C<domain=IT>

=item ner

Which Named Entity Recognizer to use:
C<ner=NameTag> (default),
or C<ner=simple>,
or C<ner=none>

=back

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

