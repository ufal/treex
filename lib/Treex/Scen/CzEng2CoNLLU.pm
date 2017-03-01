package Treex::Scen::CzEng2CoNLLU;
use Moose;
use Treex::Core::Common;

has to => (is=>'ro', isa=>'Str', default=>'-');

has substitute => (is=>'ro', isa=>'Str', default=>'');

sub get_scenario_string {
    my ($self) = @_;

    my $scen = join "\n",
    # HamleDT::Udep expects the label in attribute 'deprel' (even if they are afuns actually).
    # Store the original PoS tag in conll/pos attribute which will be printed to the XPOS column of CoNLL-U.
    q{Util::Eval anode='$.set_deprel($.afun); $.set_conll_pos($.tag);'},

    # English
    'A2A::ConvertTags input_driver=en::penn language=en',
    'A2A::EN::EnhanceInterset language=en',
    'W2A::EN::QuotesStyle language=en',

    # Czech
    # HamleDT::CS::Harmonize was created for transforming gold PDT data,
    # but it works even for automatically annotated data
    # (and even the fix_annotation_errors() method changes the trees here and there).
    # The most important work of HamleDT::CS::Harmonize could be done with
    #  'A2A::ConvertTags input_driver=cs::pdt language=cs',
    #  'A2A::CS::RemoveFeaturesFromLemmas language=cs',
    # but we also need to get rid of non-HamleDT afuns like AtrAtr, AtrAdv or Apos.
    'HamleDT::CS::Harmonize language=cs change_bundle_id=0',

    # Conversion of Prague/HamleDT-style dependencies to UD-style
    'HamleDT::Udep store_orig_filename=0',
    q{Util::Eval anode='$.set_deprel("dep") if $.deprel eq "dep:nr";'},

    # bundle IDs are used also in node IDs in CoNLLU, so let's make them shorter, e.g.
    # $s = 'subtitlesM-b1-00train'
    # $f = 'f000001-s5/en'
    q{Util::Eval bundle='my ($s,$f) = ($.id =~ /(.*)-(f\d+-s\d+)/); $.set_id($f); $.wild->{comment}="CzEng_section $s"'},
    # TODO: export also filter_score
    # my $score = $.get_attr("czeng/filter_score"); $.wild->{comment}="CzEng_section $s\nfilter_score $score";

    'Write::CoNLLU to=' . $self->to . ($self->substitute ? " substitute=".$self->substitute : ''),
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
