package Treex::Scen::EU2EN;
use Moose;
use Treex::Core::Common;

has domain => (
     is => 'ro',
     isa => enum( [qw(general IT)] ),
     default => 'general',
     documentation => 'domain of the input texts',
);

has resegment => (
     is => 'ro',
     isa => 'Bool',
     default => 0,
     documentation => 'Use W2A::ResegmentSentences',
);

has hideIT => (
     is => 'ro',
     isa => 'Bool',
     default => undef,
     documentation => 'Use W2A::EN::HideIT and A2W::ShowIT, default=1 iff domain=IT',
);

has gazetteer => (
     is => 'ro',
     isa => 'Bool',
     default => undef,
     documentation => 'Use W2A::EU::GazeteerMatch A2T::ProjectGazeteerInfo T2T::EU2EN::TrGazeteerItems, default=1 iff domain=IT',
);

sub BUILD {
    my ($self) = @_;
    if ($self->domain eq 'IT'){
        if (!defined $self->hideIT){
            $self->{hideIT} = 1;
        }
        if (!defined $self->gazetteer){
            $self->{gazetteer} = 0; # Blocks aren't defined yet
        }        
    }
    return;
}

sub get_scenario_string {
    my ($self) = @_;
    my $domain = $self->domain;
    my $gazetteer = $self->gazetteer;

    my $scen = join "\n",
    'Util::SetGlobal language=eu selector=src',
    $self->resegment ? 'W2A::ResegmentSentences' : (),
    $self->hideIT ? 'W2A::EN::HideIT' : (),
    "Scen::Analysis::EU domain=$domain gazetteer=$gazetteer",
    "Scen::Transfer::EU2EN domain=$domain gazetteer=$gazetteer",
    'Util::SetGlobal language=en selector=tst',
    "Scen::Synthesis::EN domain=$domain",
    $self->hideIT ? 'A2W::ShowIT' : (),
    ;

    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::EU2EN - Basque-to-English TectoMT translation

=head1 SYNOPSIS

 # From command line
 treex -Leu -Ssrc Read::Sentences from=eu.txt Scen::EU2EN Write::Sentences to=en.txt
 
 treex --dump_scenario Scen::EU2EN

=head1 DESCRIPTION

This scenario expects input Basque text segmented to sentences and stored in zone es_src.

If the input is not segmented to sentences, use C<W2A::EU::Segment> block first.
If it is segmented, but some segments contain more (linguistic) sentences
and moreover you want to store also the reference translations in the treex files,
start the scenario with

  Read::AlignedSentences eu_src=sample-eu.txt en_ref=sample-en.txt
  W2A::ResegmentSentences

=head1 PARAMETERS

=head2 domain (general, IT)

=head2 resegment

Use W2A::ResegmentSentences

=head2 hideIT

Use W2A::EN::HideIT and A2W::ShowIT,
default=1 iff domain=IT

=head2 gazetteer

Use W2A::EU::GazeteerMatch A2T::ProjectGazeteerInfo T2T::EU2EN::TrGazeteerItems
default=1 iff domain=IT

=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
