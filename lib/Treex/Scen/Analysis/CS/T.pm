package Treex::Scen::Analysis::CS::T;
use Moose;
use Treex::Core::Common;
use utf8;

has functors => (
     is => 'ro',
     isa => enum( [qw(MLProcess simple VW)] ),
     default => 'MLProcess',
);

has gazetteer => (
     is => 'ro',
     isa => 'Str',
     default => '0',
);

has valframes => (
     is => 'ro',
     isa => 'Bool',
     default => 0,
);

sub get_scenario_string {
    my ($self) = @_;

    my $scen = join "\n",
    'A2T::CS::MarkEdgesToCollapse', ####expletives=0
    'A2T::BuildTtree',
    'A2T::RehangUnaryCoordConj',
    'A2T::SetIsMember',
    'A2T::CS::SetCoapFunctors',
    'A2T::FixIsMember',
    'A2T::MarkParentheses',
    'A2T::MoveAuxFromCoordToMembers',
    'A2T::CS::MarkClauseHeads',
    'A2T::CS::MarkRelClauseHeads',
    'A2T::CS::MarkRelClauseCoref',
    #A2T::DeleteChildlessPunctuation We want quotes as t-nodes
    $self->gazetteer ? 'A2T::ProjectGazeteerInfo' : (),
    'A2T::CS::FixTlemmas',
    'A2T::CS::FixNumerals',
    'A2T::SetNodetype',
    'A2T::CS::SetFormeme use_version=2 fix_prep=0',
    'A2T::CS::SetDiathesis',
    $self->functors eq 'MLProcess' ? 'A2T::CS::SetFunctors memory=2g' : (),
    $self->functors eq 'VW' ? 'A2T::CS::SetFunctorsVW' : (),
    $self->functors ne 'VW' ? 'A2T::CS::SetMissingFunctors': (),
    'A2T::SetNodetype',
    'A2T::FixAtomicNodes',
    'A2T::CS::SetGrammatemes',
    'A2T::SetSentmod',
    $self->valframes ? 'A2T::CS::SetValencyFrameRefVW' : (),
    'A2T::CS::MarkReflexivePassiveGen',
    'A2T::CS::FixNonthirdPersSubj',
    'A2T::CS::AddPersPron',
    'T2T::SetClauseNumber',
    'A2T::CS::MarkReflpronCoref',
    'A2T::SetDocOrds',
    'Coref::CS::SetMultiGender',
    'A2T::CS::MarkTextPronCoref',
    'Coref::RearrangeLinks retain_cataphora=1',
    'Coref::DisambiguateGrammatemes',
    ;

    return $scen;
}

1;

=head1 NAME 

Treex::Scen::Analysis::CS::T - Czech analysis from a-layer to t-layer

=head1 SYNOPSIS

 treex -Lcs Read::Sentences from=my.txt Scen::Analysis::CS::M Scen::Analysis::CS::N Scen::Analysis::CS::A Scen::Analysis::CS::T Write::Treex to=my.treex.gz

=head1 DESCRIPTION

Performs t-layer analysis.

Expects tagged, lemmatized, name-tagged and syntactically parsed data,
i.e.
L<Scen::Analysis::CS::M>,
L<Scen::Analysis::CS::N>, and
L<Scen::Analysis::CS::A>
are prerequisites.

=head1 PARAMETERS

=over

=item functors

Which analyzer of functors to use:
C<functors=MLProcess> (default),
or C<functors=simple>,
or C<functors=VW>

=item gazetteer

Use W2A::GazeteerMatch A2T::ProjectGazeteerInfo?
C<gazetteer=0> (default),
or C<gazetteer=all>,
and other options -- see L<W2A::GazeteerMatch>

=item valframes

Set valency frame references to valency dictionary?
C<valframes=0> (default),
or C<valframes=1>.

=back

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

