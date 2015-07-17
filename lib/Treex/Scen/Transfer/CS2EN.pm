package Treex::Scen::Transfer::CS2EN;
use Moose;
use Treex::Core::Common;

has domain => (
     is => 'ro',
     isa => enum( [qw(general IT)] ),
     default => 'general',
     documentation => 'domain of the input texts',
);

has hmtm => (
     is => 'ro',
     isa => 'Bool',
     default => 1,
     documentation => 'Apply HMTM (TreeViterbi) with TreeLM reranking',
);

has gazetteer => (
     is => 'ro',
     isa => 'Bool',
     default => undef,
     documentation => 'Use W2A::EN::GazeteerMatch A2T::ProjectGazeteerInfo T2T::EN2CS::TrGazeteerItems',
);

sub BUILD {
    my ($self) = @_;
    if (!defined $self->gazetteer){
        $self->{gazetteer} = $self->domain eq 'IT' ? 1 : 0;
    }
    return;
}

sub get_scenario_string {
    my ($self) = @_;

    my $TM_DIR= 'data/models/translation/cs2en';

    my $scen = join "\n",
    'Util::SetGlobal language=en selector=tst',
    'T2T::CopyTtree source_language=cs source_selector=src',
    'T2T::CS2EN::TrFTryRules',
    #'T2T::CS2EN::TrFAddVariants model_dir= static_model=data/models/translation/cs2en/20141209_formeme.static.gz discr_model=data/models/translation/cs2en/20141209_formeme.maxent.gz',
    "T2T::CS2EN::TrFAddVariantsInterpol model_dir=
        models='static 1.0 $TM_DIR/20141209_formeme.static.gz
                maxent 0.5 $TM_DIR/20141209_formeme.maxent.gz'",
    'T2T::CS2EN::TrLTryRules',
    #'T2T::CS2EN::TrLAddVariants model_dir= static_model=data/models/translation/cs2en/20141209_lemma.static.gz discr_model=data/models/translation/cs2en/20141209_lemma.maxent.gz',
    "T2T::CS2EN::TrLAddVariantsInterpol model_dir=
        models='static 0.5 $TM_DIR/20141209_lemma.static.gz
                maxent 1.0 $TM_DIR/20141209_lemma.maxent.gz'",
    'T2T::EN2CS::CutVariants max_lemma_variants=7 max_formeme_variants=7',
    'T2T::FormemeTLemmaAgreement fun=Log-HM-P',
    $self->hmtm ? 'T2T::RehangToEffParents' : (),
    $self->hmtm ? 'T2T::CS2EN::TrLFTreeViterbi' : (), #lm_weight=0.2 formeme_weight=0.9 backward_weight=0.0 lm_dir=en.czeng
    $self->hmtm ? 'T2T::RehangToOrigParents' : (),
    'T2T::CS2EN::TrLFixTMErrors',
    'T2T::CS2EN::TrLFPhrases',
    'T2T::CS2EN::RemovePerspronGender' . ($self->domain eq 'IT' ? ' remove_guessed_gender=1' : ''),
    'T2T::CS2EN::FixForeignNames', # TODO test if it helps
    'T2T::CS2EN::RemoveInfinitiveSubjects', # TODO test if it helps
    'T2T::SetClauseNumber',
    #T2T::CS2EN::RearrangeNounCompounds -- hurts
    #T2T::CS2EN::DeleteSuperfluousNodes -- hurts
    'T2T::CS2EN::FixGrammatemesAfterTransfer',
    'T2T::CS2EN::FixDoubleNegative', # TODO test if it helps
    ;
    return $scen;

}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Transfer::CS2EN - Czech-to-English TectoMT transfer (no analysis, no synthesis)

=head1 SYNOPSIS

 # From command line
 treex Scen::Transfer::CS2EN Write::Treex to=translated.treex.gz -- cs_ttrees.treex.gz
 
 treex --dump_scenario Scen::Transfer::CS2EN

=head1 DESCRIPTION

This scenario expects input Czech text analyzed to t-trees in zone cs_src.
The output (translated English t-trees) will be in zone en_tst.

=head1 PARAMETERS

currently none

=head1 SEE ALSO

L<Treex::Scen::CS2EN> -- end-to-end translation scenario

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
