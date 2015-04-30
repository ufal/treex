package Treex::Scen::EN2CS;
use Moose;
use Treex::Core::Common;

my $FULL = <<'END';
Util::SetGlobal language=en selector=src
Scen::Analysis::EN
Scen::Transfer::EN2CS
Util::SetGlobal language=cs selector=tst
Scen::Synthesis::CS

END

sub get_scenario_string {
    return $FULL;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::EN2CS - English-to-Czech TectoMT translation

=head1 SYNOPSIS

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

currently none

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
