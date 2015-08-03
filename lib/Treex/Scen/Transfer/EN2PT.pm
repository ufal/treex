package Treex::Scen::Transfer::EN2PT;
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
     default => 1,
     documentation => 'Apply HMTM (TreeViterbi) with TreeLM reranking',
);

has gazetteer => (
     is => 'ro',
     isa => 'Bool',
     default => 0,
     documentation => 'Use T2T::EN2PT::TrGazeteerItems, default=0',
);

has fl_agreement => (
     is => 'ro',
     isa => enum( [qw(0 AM-P GM-P HM-P GM-Log-P HM-Log-P)] ),
     default => '0',
     documentation => 'Use T2T::FormemeTLemmaAgreement with a specified function as parameter',
);

has lxsuite_key => (
    is => 'ro',
    isa => 'Str',
    default => 'nlx.qtleap.13417612987549387402',
    documentation => 'Secret password to access Portuguese servers',
);

has lxsuite_host => (
    is => 'ro',
    isa => 'Str',
    default => '194.117.45.198',
);

has lxsuite_port => (
    is => 'ro',
    isa => 'Str',
    default => '10000',
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
    return;
}


sub get_scenario_string {
    my ($self) = @_;

    my $TM_DIR= 'data/models/translation/en2pt';
    my $IT_LEMMA_MODELS = '';
    my $IT_FORMEME_MODELS = '';
    if ($self->tm_adaptation eq 'interpol'){
        #TODO
        #$IT_LEMMA_MODELS = "static 0.5 IT/batch1a-lemma.static.gz\n      maxent 1.0 IT/batch1a-lemma.maxent.gz";
        #$IT_FORMEME_MODELS = "static 1.0 IT/batch1a-formeme.static.gz\n      maxent 0.5 IT/batch1a-formeme.maxent.gz";
    }

    my $scen = join "\n",
    'Util::SetGlobal lxsuite_host=' . $self->lxsuite_host . ' lxsuite_port=' . $self->lxsuite_port,
    'Util::SetGlobal lxsuite_key=' . $self->lxsuite_key,
    'Util::SetGlobal language=pt selector=tst',
    'T2T::CopyTtree source_language=en source_selector=src',
    $self->gazetteer ? 'T2T::TrGazeteerItems src_lang='.$self->src_lang : (),
    #'T2T::EN2PT::TrLTryRules',
    "T2T::TrFAddVariantsInterpol model_dir=$TM_DIR models='
      static 1.0 formeme.static.model.20150119.gz
      maxent 0.5 formeme.maxent.model.20150119.gz
      $IT_FORMEME_MODELS'",
    "T2T::TrLAddVariantsInterpol model_dir=$TM_DIR models='
      static 0.5 tlemma.static.model.20150119.gz
      maxent 1.0 tlemma.maxent.model.20150119.gz
      $IT_LEMMA_MODELS'",
    $self->fl_agreement ? 'T2T::FormemeTLemmaAgreement fun='.$self->fl_agreement : (),
    'Util::DefinedAttr tnode=t_lemma,formeme message="after simple transfer"',
    'T2T::SetClauseNumber',
    #T2T::RecoverUnknownLemmas.pm
    # 'T2T::FixPunctFormemes',
    'T2T::FixFormemeWrtNodetype',
    'T2T::EN2PT::Noun1Noun2_To_Noun2DeNoun1',
    'T2T::EN2PT::MoveAdjsAfterNouns',
    'T2T::EN2PT::FixPersPron',
    'T2T::EN2PT::FixThereIs',
    'T2T::EN2PT::AddRelpronBelowRc',
    'T2T::EN2PT::TurnVerbLemmaToAdjectives',
    'T2T::EN2PT::FixPunctuation',
    #$self->domain eq 'IT' ? 'T2T::EN2PT::TrL_ITdomain' : (),
    ;

    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Transfer::EN2PT - English-to-Portuguese TectoMT transfer (no analysis, no synthesis)

=head1 SYNOPSIS

 # From command line
 treex Scen::Transfer::EN2PT Write::Treex to=translated.treex.gz -- en_ttrees.treex.gz

 treex --dump_scenario Scen::Transfer::EN2PT

=head1 DESCRIPTION

This scenario expects input English text analyzed to t-trees in zone en_src.
The output (translated Portuguese t-trees) will be in zone pt_tst.

=head1 PARAMETERS

TODO

=head1 SEE ALSO

L<Treex::Scen::EN2PT> -- end-to-end translation scenario

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

Luís Gomes <luis.gomes@di.fc.ul.pt>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
