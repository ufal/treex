package Treex::Scen::Transfer::EN2ES;
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
    return;
}


sub get_scenario_string {
    my ($self) = @_;
    
    my $TM_DIR= 'data/models/translation/en2es';
    my $IT_LEMMA_MODELS = '';
    my $IT_FORMEME_MODELS = '';
    if ($self->tm_adaptation eq 'interpol'){
        $IT_LEMMA_MODELS = "static 0.5 IT/20150728_batch1a-tlemma.static.gz\n      maxent 1.0 IT/20150728_batch1a-tlemma.maxent.gz";
        $IT_FORMEME_MODELS = "static 1.0 IT/20150728_batch1a-formeme.static.gz\n      maxent 0.5 IT/20150728_batch1a-formeme.maxent.gz";
    }
    
    my $scen = join "\n",
    'Util::SetGlobal language=es selector=tst',
    'T2T::CopyTtree source_language=en source_selector=src',
    $self->gazetteer ? 'T2T::TrGazeteerItems src_lang='.$self->src_lang : (),
    'T2T::EN2ES::TrLTryRules',
    $self->domain eq 'IT' ? 'T2T::TrLApplyTbxDictionary tbx=data/dictionaries/MicrosoftTermCollection.es.tbx tbx_src_id=en-US tbx_trg_id=es-es analysis=data/dictionaries/MicrosoftTermCollection.es.streex analysis_src_language=en analysis_src_selector=src analysis_trg_language=es analysis_trg_selector=trg src_blacklist=data/dictionaries/MicrosoftTermCollection.en-es.src.blacklist.txt' : (),

    "T2T::TrFAddVariantsInterpol model_dir=$TM_DIR models='
      static 1.0 Pilot1_formeme.static.gz
      maxent 0.5 Pilot1_formeme.maxent.gz
      $IT_FORMEME_MODELS'",
    "T2T::TrLAddVariantsInterpol model_dir=$TM_DIR models='
      static 0.5 Pilot1_tlemma.static.gz
      maxent 1.0 Pilot1_tlemma.maxent.gz
      $IT_LEMMA_MODELS'",
    $self->fl_agreement ? 'T2T::FormemeTLemmaAgreement fun='.$self->fl_agreement : (),
    'Util::DefinedAttr tnode=t_lemma,formeme message="after simple transfer"',

    #$self->domain eq 'IT' ? 'T2T::EN2ES::TrL_ITdomain' : (),
    'T2T::SetClauseNumber',
    ;

    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Transfer::EN2ES - English-to-Spanish TectoMT transfer (no analysis, no synthesis)

=head1 SYNOPSIS

 # From command line
 treex Scen::Transfer::EN2ES Write::Treex to=translated.treex.gz -- en_ttrees.treex.gz
 
 treex --dump_scenario Scen::Transfer::EN2ES

=head1 DESCRIPTION

This scenario expects input English text analyzed to t-trees in zone en_src.
The output (translated Spanish t-trees) will be in zone es_tst.

=head1 PARAMETERS

currently none

=head1 SEE ALSO

L<Treex::Scen::EN2ES> -- end-to-end translation scenario

=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>
Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
