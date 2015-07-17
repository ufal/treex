package Treex::Scen::EN2CS;
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
     documentation => 'Use W2A::EN::GazeteerMatch A2T::ProjectGazeteerInfo T2T::EN2CS::TrGazeteerItems, default=1 iff domain=IT',
);


sub BUILD {
    my ($self) = @_;
    if ($self->domain eq 'IT'){
        if (!defined $self->hideIT){
            $self->{hideIT} = 1;
        }
        if (!defined $self->gazetteer){
            $self->{gazetteer} = 1;
        }        
    }
    return;
}


sub get_scenario_string {
    my ($self) = @_;
    my $domain = $self->domain;
    my $gazetteer = $self->gazetteer;

    my $scen = join "\n",
    'Util::SetGlobal language=en selector=src',
    $self->resegment ? 'W2A::ResegmentSentences' : (),
    $self->hideIT ? 'W2A::EN::HideIT' : (),
    "Scen::Analysis::EN domain=$domain gazetteer=$gazetteer",
    "Scen::Transfer::EN2CS domain=$domain gazetteer=$gazetteer",
    'Util::SetGlobal language=cs selector=tst',
    "Scen::Synthesis::CS domain=$domain",
    $self->hideIT ? 'A2W::ShowIT' : (),
    ;
    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::EN2CS - English-to-Czech TectoMT translation

=head1 SYNOPSIS

 Scen::EN2CS domain=IT resegment=1

 # From command line
 treex -Len -Ssrc Read::Sentences from=en.txt Scen::EN2CS Write::Sentences to=cs.txt
 
 treex --dump_scenario Scen::EN2CS

=head1 DESCRIPTION

This scenario expects input English text segmented to sentences and stored in zone en_src.

If the input is not segmented to sentences, use C<W2A::EN::Segment> block first.
If it is segmented, but some segments contain more (linguistic) sentences
and moreover you want to store also the reference translations in the treex files,
start the scenario with

  Read::AlignedSentences en_src=sample-en.txt cs_ref=sample-cs.txt
  W2A::ResegmentSentences

=head1 PARAMETERS

=head2 domain (general, IT)

=head2 resegment

Use W2A::ResegmentSentences

=head2 hideIT

Use W2A::EN::HideIT and A2W::ShowIT,
default=1 iff domain=IT

=head2 gazetteer

Use W2A::EN::GazeteerMatch A2T::ProjectGazeteerInfo T2T::EN2CS::TrGazeteerItems
default=1 iff domain=IT

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
