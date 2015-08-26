package Treex::Scen::NL2EN;
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
     documentation => 'Use W2A::GazeteerMatch A2T::ProjectGazeteerInfo T2T::TrGazeteerItems, default=1 if domain=IT',
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
        $self->{src_lang} = "nl";
        $self->{trg_lang} = "en";
    }
    return;
}

sub get_scenario_string {
    my ($self) = @_;
    my $params = $self->args_str;

    my $scen = join "\n",
    'Util::SetGlobal language=nl selector=src',
    $self->resegment ? 'W2A::ResegmentSentences' : (),
    $self->hideIT ? 'W2A::HideIT' : (),
    "Scen::Analysis::NL $params",
    "Scen::Transfer::NL2EN $params",
    'Util::SetGlobal language=en selector=tst',
    "Scen::Synthesis::EN $params",
    $self->hideIT ? 'A2W::ShowIT' : (),
    ;
    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::NL2EN - Dutch-to-English TectoMT translation

=head1 SYNOPSIS

 # From command line
 treex -Lnl -Ssrc Read::Sentences from=nl.txt Scen::NL2EN Write::Sentences to=en.txt
 
 treex --dump_scenario Scen::NL2EN

=head1 DESCRIPTION

This scenario expects input Dutch text segmented to sentences and stored in zone nl_src.

If the input is not segmented to sentences, use C<W2A::NL::Segment> block first.
If it is segmented, but some segments contain more (linguistic) sentences
and moreover you want to store also the reference translations in the treex files,
start the scenario with

  Read::AlignedSentences nl_src=sample-nl.txt en_ref=sample-en.txt
  W2A::ResegmentSentences

=head1 PARAMETERS

=head2 domain (general, IT)

=head2 resegment

Use W2A::ResegmentSentences

=head2 gazetteer

Use W2A::GazeteerMatch A2T::ProjectGazeteerInfo T2T::TrGazeteerItems
default=1 iff domain=IT

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>
Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
