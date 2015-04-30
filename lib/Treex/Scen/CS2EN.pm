package Treex::Scen::CS2EN;
use Moose;
use Treex::Core::Common;

my $FULL = <<'END';
Util::SetGlobal language=cs selector=src
Scen::Analysis::CS
Scen::Transfer::CS2EN
Util::SetGlobal language=en selector=tst
Scen::Synthesis::EN

END

sub get_scenario_string {
    return $FULL;
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

If the input is not segmented to sentences, use C<W2A::CS::Segment> block first.
If it is segmented, but some segments contain more (linguistic) sentences
and moreover you want to store also the reference translations in the treex files,
start the scenario with

  Read::AlignedSentences cs_src=sample-cs.txt en_ref=sample-en.txt
  W2A::ResegmentSentences

=head1 PARAMETERS

currently none

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
