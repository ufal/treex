package Treex::Scen::CzEng2CoNLLU;
use Moose;
use Treex::Core::Common;

has to => (is=>'ro', isa=>'Str', default=>'-');

sub get_scenario_string {
    my ($self) = @_;

    my $scen = join "\n",
    q{Util::Eval anode='$.set_deprel($.afun)'},
    'A2A::ConvertTags input_driver=cs::pdt language=cs',
    'A2A::ConvertTags input_driver=en::penn language=en',
    'A2A::EN::EnhanceInterset',
    'HamleDT::Udep store_orig_filename=0',

    # bundle IDs are used also in node IDs in CoNLLU, so let's make them shorter, e.g.
    # $s = 'subtitlesM-b1-00train'
    # $f = 'f000001-s5/en'
    q{Util::Eval bundle='my ($s,$f) = ($.id =~ /(.*)-(f\d+-s\d+)/); $.set_id($f); $.wild->{comment}="CzEng_section $s"'},

    'Write::CoNLLU to=' . $self->to,
    ;
    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::CzEng2CoNLLU - convert CzEng to Universal Dependencies

=head1 SYNOPSIS

 # convert all *.treex.gz files into *.conllu
 treex Scen::CzEng2CoNLLU to=. -- *.treex.gz

=head1 DESCRIPTION

=head1 PARAMETERS

=head2 to

Where to save the output CoNLL-U?
Forwarded as the C<to> parameter for the C<Write::CoNLLU> block.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
