package Treex::Scen::EN2EU;
use Moose;
use Treex::Core::Common;
with 'Treex::Core::RememberArgs';

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
     documentation => 'Use W2A::HideIT and A2W::ShowIT, default=1 iff domain=IT',
);

has gazetteer => (
     is => 'ro',
     isa => 'Str',
     documentation => 'Use W2A::EN::GazeteerMatch A2T::ProjectGazeteerInfo T2T::TrGazeteerItems, default=all if domain=IT',
);

sub BUILD {
    my ($self) = @_;

    if (!defined $self->hideIT){
        $self->{hideIT} = $self->domain eq 'IT' ? 1 : 0;
    }
    if (!defined $self->gazetteer){
        $self->{gazetteer} = $self->domain eq 'IT' ? 'all' : '0';
    }
    if ($self->gazetteer) {
        $self->{src_lang} = "en";
        $self->{trg_lang} = "eu";
    }
    return;
}

sub get_scenario_string {
    my ($self) = @_;
    my $params = $self->args_str;

    my $scen = join "\n",
    'Util::SetGlobal language=en selector=src',
    $self->resegment ? 'W2A::ResegmentSentences' : (),
    $self->hideIT ? 'W2A::HideIT' : (),
    "Scen::Analysis::EN $params",
    "Scen::Transfer::EN2EU $params",
    'Util::SetGlobal language=eu selector=tst',
    "Scen::Synthesis::EU $params",
    $self->hideIT ? 'A2W::ShowIT' : (),
    ;
    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::EN2EU - English-to-Basque TectoMT translation

=head1 SYNOPSIS

 # From command line
 treex -Len -Ssrc Read::Sentences from=en.txt Scen::EN2EU Write::Sentences to=eu.txt
 
 treex --dump_scenario Scen::EN2EU

=head1 DESCRIPTION

This scenario expects input English text segmented to sentences and stored in zone en_src.

If the input is not segmented to sentences, use C<W2A::EN::Segment> block first.
If it is segmented, but some segments contain more (linguistic) sentences
and moreover you want to store also the reference translations in the treex files,
start the scenario with

  Read::AlignedSentences en_src=sample-en.txt eu_ref=sample-eu.txt
  W2A::ResegmentSentences

=head1 PARAMETERS

=head2 domain (general, IT)

=head2 resegment

Use W2A::ResegmentSentences

=head2 hideIT

Use W2A::HideIT and A2W::ShowIT,
default=1 iff domain=IT

=head2 gazetteer

Use W2A::EN::GazeteerMatch A2T::ProjectGazeteerInfo T2T::TrGazeteerItems
One can specify the sources which should be used as gazetteers.
Values: 
    'all' - use all sources contained in the gazetteers
    '0' - do not use gazetteers
    'libreoffice' - use only gazetteers extracted from the Libre Office localization
    'libreoffice,vlc' - use gazetteers extracted from the Libre Office and VLC localization
If 'domain=IT', 'all' is set by default.

=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
