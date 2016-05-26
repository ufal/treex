package Treex::Scen::CzEng16;
use Moose;
use Treex::Core::Common;
with 'Treex::Core::RememberArgs';

has resegment => (
     is => 'ro',
     isa => 'Bool',
     default => 0,
     documentation => 'Use W2A::ResegmentSentences',
);

sub BUILD {
    my ($self) = @_;
    # running BART for coreference resolution in English
    $self->{coref} = "BART";
    return;
}

sub get_scenario_string {
    my ($self) = @_;
    my $params = $self->args_str;

    my $scen = join "\n",
    'Util::SetGlobal language=en selector=src',
    $self->resegment ? 'W2A::ResegmentSentences' : (),
    "Scen::Analysis::EN functors=VW $params",
    'Util::SetGlobal language=cs selector=src',
    $self->resegment ? 'W2A::ResegmentSentences' : (),
    "Scen::Analysis::CS $params",
    # TODO: add align blocks here
    # ???
    # alignment of coreferential expressions
    'Align::T::Supervised::Resolver language=en,cs align_trg_lang=en node_types=all_anaph',
    ;
    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::CzEng16 - a scenario for generating CzEng 1.6

=head1 SYNOPSIS

 Scen::EN2CS domain=IT resegment=1

 # From command line
 treex -Len -Ssrc Read::Sentences from=en.txt Scen::EN2CS Write::Sentences to=cs.txt
 
 treex --dump_scenario Scen::EN2CS

=head1 DESCRIPTION

This scenario expects input English text segmented to sentences and stored in zone en_src.

If the input is not segmented to sentences, use C<W2A::EN::Segment> block first:

 cat en.txt | treex -Len -Ssrc W2A::EN::Segment Scen::EN2CS Write::Sentences > cs.txt

If it is segmented, but some segments contain more (linguistic) sentences
and moreover you want to store also the reference translations in the treex files, use:

  treex Read::AlignedSentences en_src=sample-en.txt cs_ref=sample-cs.txt \
        Scen::EN2CS resegment=1 \
        Write::Treex to=sample.treex.gz

=head1 PARAMETERS

=head2 domain (general, IT)

=head2 resegment

Use W2A::ResegmentSentences

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
