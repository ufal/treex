package Treex::Scen::CS2EN;
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
     documentation => 'Use W2A::GazeteerMatch A2T::ProjectGazeteerInfo T2T::TrGazeteerItems, default=all if domain=IT',
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
        $self->{src_lang} = "cs";
        $self->{trg_lang} = "en";
    }
    return;
}

sub get_scenario_string {
    my ($self) = @_;
    my $params = $self->args_str;

    my $scen = join "\n",
    'Util::SetGlobal language=cs selector=src',
    $self->resegment ? 'W2A::ResegmentSentences' : (),
    $self->hideIT ? 'W2A::HideIT' : (),
    "Scen::Analysis::CS $params",
    "Scen::Transfer::CS2EN $params",
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

Treex::Scen::CS2EN - Czech-to-English TectoMT translation

=head1 SYNOPSIS

 # From command line
 treex -Lcs -Ssrc Read::Sentences from=cs.txt Scen::CS2EN Write::Sentences to=en.txt
 
 treex --dump_scenario Scen::CS2EN

=head1 DESCRIPTION

This scenario expects input Czech text segmented to sentences and stored in zone cs_src.
See L<Treex::Scen::EN2CS> for details.

=head1 PARAMETERS

=head2 domain (general, IT)

=head2 resegment

Use W2A::ResegmentSentences

=head2 gazetteer

Use W2A::GazeteerMatch A2T::ProjectGazeteerInfo T2T::TrGazeteerItems
default=1 iff domain=IT

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
