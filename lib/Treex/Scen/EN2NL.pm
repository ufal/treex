package Treex::Scen::EN2NL;
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

sub BUILD {
    my ($self) = @_;

    if (!defined $self->hideIT){
        $self->{hideIT} = $self->domain eq 'IT' ? 1 : 0;
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
    "Scen::Transfer::EN2NL $params",
    'Util::SetGlobal language=nl selector=tst',
    "Scen::Synthesis::NL $params",
    $self->hideIT ? 'A2W::ShowIT' : (),
    ;
    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::EN2NL - English-to-Dutch TectoMT translation

=head1 SYNOPSIS

 Scen::EN2NL domain=IT resegment=1

 # From command line
 treex -Len -Ssrc Read::Sentences from=en.txt Scen::EN2NL Write::Sentences to=nl.txt
 
 treex --dump_scenario Scen::EN2NL

=head1 DESCRIPTION

This scenario expects input English text segmented to sentences and stored in zone en_src.

If the input is not segmented to sentences, use C<W2A::EN::Segment> block first.
If it is segmented, but some segments contain more (linguistic) sentences
and moreover you want to store also the reference translations in the treex files,
start the scenario with

  Read::AlignedSentences en_src=sample-en.txt nl_ref=sample-nl.txt
  W2A::ResegmentSentences

=head1 PARAMETERS

=head2 domain (general, IT)

=head2 resegment

Use W2A::ResegmentSentences

=head2 hideIT

Use W2A::HideIT and A2W::ShowIT,
default=1 iff domain=IT

#=head2 gazetteer
#
#Use W2A::EN::GazeteerMatch A2T::ProjectGazeteerInfo T2T::EN2CS::TrGazeteerItems
#default=1 iff domain=IT

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>
Ondřej Dušek <odusek@ufal.mff.cuni.cz>
Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
