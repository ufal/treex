package Treex::Scen::Transfer::NL2EN;
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

has lm_dir => (
    is => 'ro',
    isa => 'Str',
    default => 'auto',
    documentation => 'HTMT Tree LM directory (default chosen based on domain)',
);

has lm_weight => (
    is            => 'ro',
    isa           => 'Num',
    default       => 0.2,
    documentation => 'Weight of tree language model (or transition) logprobs.',
);

has formeme_weight => (
    is            => 'ro',
    isa           => 'Num',
    default       => 1.5,
    documentation => 'Weight of the Tree LM formeme forward logprobs.',
);

has backward_weight => (
    is            => 'ro',
    isa           => 'Num',
    default       => 0,
    documentation => 'Weight of the Tree LM backward lemma logprobs (1-forward)'
);

has gazetteer => (
     is => 'ro',
     isa => 'Str',
     default => '0',
     documentation => 'Use T2T::TrGazeteerItems, default=0',
);

has fl_agreement => (
     is => 'ro',
     isa => enum( [qw(0 AM-P GM-P HM-P GM-Log-P HM-Log-P)] ),
     default => '0',
     documentation => 'Use T2T::FormemeTLemmaAgreement with a specified function as parameter',
);

# TODO gazetteers should work without any dependance on source language here
has src_lang => (
    is => 'ro',
    isa => 'Str',
    documentation => 'Gazetteers are defined for language pairs. Both source and target languages must be specified.',
);

sub BUILD {
    my ($self) = @_;
    if ($self->tm_adaptation eq 'auto'){
        $self->{tm_adaptation} = $self->domain eq 'IT' ? 'interpol' : 'no';
    }
    if ($self->lm_dir eq 'auto'){
        $self->{lm_dir} = $self->domain eq 'IT' ? 'en.superuser' : 'en.czeng';
    }
    return;
}

sub get_scenario_string {
    my ($self) = @_;
    
    my $TM_DIR= 'data/models/translation/nl2en';

    my $IT_LEMMA_MODELS = '';
    my $IT_FORMEME_MODELS = '';
    if ($self->tm_adaptation eq 'interpol'){
        $IT_LEMMA_MODELS = "static 0.5 IT/20150725_batch1q-tlemma.static.gz\n      maxent 1.0 IT/20150725_batch1q-tlemma.maxent.gz";
        $IT_FORMEME_MODELS = "static 1.0 IT/20150725_batch1q-formeme.static.gz\n      maxent 0.5 IT/20150725_batch1q-formeme.maxent.gz";
    }
    my $HMTM_PARAMS = '';
    if ($self->hmtm){
        $HMTM_PARAMS = 'lm_dir=' . $self->lm_dir 
                . ' lm_weight=' . $self->lm_weight 
                . ' formeme_weight=' . $self->formeme_weight 
                . ' backward_weight=' . $self->backward_weight;
    }

    my $scen = join "\n",
    'Util::SetGlobal language=en selector=tst',
    'T2T::CopyTtree source_language=nl source_selector=src',
    $self->gazetteer ? 'T2T::TrGazeteerItems src_lang='.$self->src_lang : (),
    "T2T::TrFAddVariantsInterpol model_dir=$TM_DIR models='
      static 1.0 20150725_formeme.static.min_2.minpc_1.gz
      maxent 0.5 20150220_formeme.maxent.gz
      $IT_FORMEME_MODELS'",
    "T2T::TrLAddVariantsInterpol model_dir=$TM_DIR models='
      static 0.5 20150725_tlemma.static.min_2.minpc_1.gz
      maxent 1.0 20150220_tlemma.maxent.gz
      $IT_LEMMA_MODELS'",
    'T2T::CutVariants max_lemma_variants=7 max_formeme_variants=7',
    $self->fl_agreement ? 'T2T::FormemeTLemmaAgreement fun='.$self->fl_agreement : (),
    $self->hmtm ? 'T2T::RehangToEffParents' : (),
    $self->hmtm ? "T2T::EN2EN::TrLFTreeViterbi $HMTM_PARAMS" : (),
    $self->hmtm ? 'T2T::RehangToOrigParents' : (),
    'Util::DefinedAttr tnode=t_lemma,formeme message="after simple transfer"',
    'T2T::FixGrammatemesAfterTransfer',
    'T2T::SetClauseNumber',
    ;
    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Transfer::NL2EN - Dutch-to-English TectoMT transfer (no analysis, no synthesis)

=head1 SYNOPSIS

 # From command line
 treex Scen::Transfer::NL2EN Write::Treex to=translated.treex.gz -- nl_ttrees.treex.gz
 
 treex --dump_scenario Scen::Transfer::NL2EN

=head1 DESCRIPTION

This scenario expects input Dutch text analyzed to t-trees in zone nl_src.
The output (translated English t-trees) will be in zone en_tst.

=head1 PARAMETERS

TODO

=head1 SEE ALSO

L<Treex::Scen::NL2EN> -- end-to-end translation scenario

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Michal Novák <mnovak@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
