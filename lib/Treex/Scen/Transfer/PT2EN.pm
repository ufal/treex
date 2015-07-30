package Treex::Scen::Transfer::PT2EN;
use Moose;
use Treex::Core::Common;

has domain => (
     is => 'ro',
     isa => enum( [qw(general IT)] ),
     default => 'general',
     documentation => 'domain of the input texts',
);

has tm_adaptation => (
     is => 'ro',
     isa => enum( [qw(auto no 0 interpol)] ),
     default => 'auto',
     documentation => 'domain adaptation of Translation Models to IT domain',
);

has hmtm => (
     is => 'ro',
     isa => 'Bool',
     default => 0,
     documentation => 'Apply HMTM (TreeViterbi) with TreeLM reranking',
);

# TODO
has gazetteer => (
     is => 'ro',
     isa => 'Bool',
     default => 0,
     documentation => 'Use T2T::PT2EN::TrGazeteerItems, default=0',
);

has fl_agreement => (
     is => 'ro',
     isa => enum( [qw(0 AM-P GM-P HM-P GM-Log-P HM-Log-P)] ),
     default => '0',
     documentation => 'Use T2T::FormemeTLemmaAgreement with a specified function as parameter',
);

sub BUILD {
    my ($self) = @_;
    if ($self->tm_adaptation eq 'auto'){
        $self->{tm_adaptation} = $self->domain eq 'IT' ? 'interpol' : 'no';
    }
    return;
}

sub get_scenario_string {
    my ($self) = @_;

    my $IT_LEMMA_MODELS = '';
    my $IT_FORMEME_MODELS = '';
    if ($self->tm_adaptation eq 'interpol'){
        # TODO
        #$IT_LEMMA_MODELS = "static 0.5 IT/batch1q-lemma.static.gz\n      maxent 1.0 IT/batch1q-lemma.maxent.gz";
        #$IT_FORMEME_MODELS = "static 1.0 IT/batch1q-formeme.static.gz\n      maxent 0.5 IT/batch1q-formeme.maxent.gz";
    }

    my $scen = join "\n",
    'Util::SetGlobal language=en selector=tst',
    'T2T::CopyTtree source_language=pt source_selector=src',
    #'T2T::PT2EN::TrFTryRules',
    "T2T::TrFAddVariantsInterpol model_dir=data/models/translation/pt2en models='
      static 1.0 formeme.static.model.20150119.gz
      maxent 0.5 formeme.maxent.model.20150119.gz
      $IT_FORMEME_MODELS'",
    #'T2T::PT2EN::TrLTryRules',
    "T2T::TrLAddVariantsInterpol model_dir=data/models/translation/pt2en models='
      static 0.5 tlemma.static.model.20150119.gz
      maxent 1.0 tlemma.maxent.model.20150119.gz
      $IT_LEMMA_MODELS'",
    'T2T::CutVariants max_lemma_variants=7 max_formeme_variants=7',
    $self->fl_agreement ? 'T2T::FormemeTLemmaAgreement fun='.$self->fl_agreement : (),
    #$self->hmtm ? 'T2T::RehangToEffParents' : (),
    #$self->hmtm ? 'T2T::PT2EN::TrLFTreeViterbi' : (),
    #$self->hmtm ? 'T2T::RehangToOrigParents' : (),

    #'T2T::FixPunctFormemes',
    'T2T::SetClauseNumber',
    #'T2T::PT2EN::RestoreUrl',
    'T2T::PT2EN::MoveAdjsBeforeNouns',
    'T2T::PT2EN::FixThereIs',
    'T2T::PT2EN::FixValency',
    ;
    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Transfer::PT2EN - Portuguese-to-English TectoMT transfer (no analysis, no synthesis)

=head1 SYNOPSIS

 # From command line
 treex Scen::Transfer::PT2EN Write::Treex to=translated.treex.gz -- pt_ttrees.treex.gz

 treex --dump_scenario Scen::Transfer::PT2EN

=head1 DESCRIPTION

This scenario expects input Portuguese text analyzed to t-trees in zone pt_src.
The output (translated English t-trees) will be in zone en_tst.

=head1 PARAMETERS

TODO

=head1 SEE ALSO

L<Treex::Scen::PT2EN> -- end-to-end translation scenario

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
