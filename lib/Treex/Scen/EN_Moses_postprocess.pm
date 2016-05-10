package Treex::Scen::EN_Moses_postprocess;
use Moose;
use Treex::Core::Common;
with 'Treex::Core::RememberArgs';

has resegment => (
     is => 'ro',
     isa => 'Bool',
     default => 1,
     documentation => 'Used W2A::ResegmentSentences, now use Misc::JoinBundles',
);

has showIT => (
     is => 'ro',
     isa => 'Bool',
     default => '1',
     documentation => 'Use W2A::HideIT and A2W::ShowIT',
);

has gazetteer => (
     is => 'ro',
     isa => 'Str',
     default => 'all',
     documentation => 'Use W2A::EN::GazeteerMatch A2T::ProjectGazeteerInfo, default=0',
);

has pretokenized => (
    is => 'ro',
    isa => 'Bool',
    default => '0',
    documentation => 'Is the input pretokenized? If set to 1, will only tokenize on whitespace.'
);

has detokenize => (
    is => 'ro',
    isa => 'Bool',
    default => '1',
    documentation => 'Detokenize the output (instead of leaving tokens space-separated)'
);

has replacements_file => (
    is => 'ro',
    isa => 'Str',
    documentation => 'Filename for storing the replacements',
    default => 'replacements.dump',
);

has gazetteer_translations_file => (
    is => 'ro',
    isa => 'Str',
    documentation => 'Filename for storing the replacements',
    default => 'gazetteer_translations.dump',
);

has bundle_ids_file => (
    is => 'ro',
    isa => 'Str',
    documentation => 'Filename for storing the bundle ids',
    default => 'bundle_ids.txt',
);

sub get_scenario_string {
    my ($self) = @_;

    my $scen = join "\n",
    # 'Util::SetGlobal selector=src',
    # 'Util::SetGlobal language=cs',
    # 'Read::Sentences',
    $self->showIT ? 'Read::BundleWildAttribute attribute=entities from=' . $self->replacements_file : (),
    $self->showIT ? 'A2W::ShowIT source_selector=' : (),
    $self->gazetteer ? 'Read::BundleWildAttribute attribute=gazetteer_translations from=' . $self->gazetteer_translations_file : (),
    $self->gazetteer ? 'A2W::ShowGazetteerItems' : (),
    ($self->pretokenized ? 'W2A::TokenizeOnWhitespace' : 'W2A::Tokenize') . ' language=all',
    'A2A::ProjectCase',
    'A2W::CapitalizeSentStart',
    $self->detokenize ? 'A2W::Detokenize remove_final_space=1' : 'A2W::ConcatenateTokens',
    $self->resegment ? 'Read::BundleIds from=' . $self->bundle_ids_file : (),
    $self->resegment ? 'Misc::JoinBundles' : (),
    'Write::Sentences',
    ;

    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::EN_Moses_postprocess - English postprocessing for Moses.
Especially useful in the Chiméra setup and/or in the IT domain setting.

=head1 SYNOPSIS

 # From command line
 treex -Lcs Read::AlignedSentences en=input.txt cs=translation.txt Scen::EN_Moses_postprocess > output.txt

=head1 DESCRIPTION

Treex analysis for Moses, parametrizable as to which púarts to run or not

=over

=item read in

=item sentence segmentation

=item hideIT

=item tokenization

=item gazetteers

=item tagging and lemmatization

=item writeout

=back

=head1 PARAMETERS

=head2 domain (general, IT)

=head2 tagger (Morce, MorphoDiTa)

Morce = W2A::EN::TagMorce

MorphoDiTa = W2A::EN::TagMorphoDiTa

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>
Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015-2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
