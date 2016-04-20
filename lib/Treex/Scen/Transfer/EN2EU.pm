package Treex::Scen::Transfer::EN2EU;
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

has terminology => (
     is => 'ro',
     isa => enum( [qw(auto no 0 yes)] ),
     default => 'auto',
     documentation => 'Use T2T::TrLApplyTbxDictionary with Microsoft Terminology Collection',
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

    if ($self->terminology eq 'auto'){
        $self->{terminology} = $self->domain eq 'IT' ? 'yes' : 'no';
    }
    return;
}


sub get_scenario_string {
    my ($self) = @_;
    
    my $TM_DIR= 'data/models/translation/en2eu';
    
    my $IT_LEMMA_MODELS = '';
    my $IT_FORMEME_MODELS = '';
    if ($self->tm_adaptation eq 'interpol'){
        $IT_LEMMA_MODELS = "static 0.5 IT/20160415_batch1a-tlemma.static.gz\n      maxent 1.0 IT/20160415_batch1a-tlemma.maxent.gz";
        $IT_FORMEME_MODELS = "static 1.0 IT/20160415_batch1a-formeme.static.gz\n      maxent 0.5 IT/20160415_batch1a-formeme.maxent.gz";
    }

    my $scen = join "\n",
    'Util::SetGlobal language=eu selector=tst',
    'T2T::CopyTtree source_language=en source_selector=src',
    $self->gazetteer ? 'T2T::TrGazeteerItems src_lang='.$self->src_lang : (),
    'T2T::EN2EU::TrLTryRules',
    'T2T::EN2EU::RemoveRelPron',

    $self->terminology eq 'yes' ? 'T2T::TrLApplyTbxDictionary tbx=data/dictionaries/MicrosoftTermCollection.eu.tbx tbx_src_id=en-US tbx_trg_id=eu-es analysis=@data/dictionaries/MicrosoftTermCollection.eu.filelist analysis_src_language=en analysis_src_selector=src analysis_trg_language=eu analysis_trg_selector=trg src_blacklist=data/dictionaries/MicrosoftTermCollection.en-eu.src.blacklist.txt' : (),

    "T2T::TrFAddVariantsInterpol model_dir=$TM_DIR models='
      static 1.0 20160415_formeme.static.gz
      maxent 0.5 20160415_formeme.maxent.gz
      $IT_FORMEME_MODELS'",
    "T2T::TrLAddVariantsInterpol model_dir=$TM_DIR models='
      static 0.5 20160415_tlemma.static.gz
      maxent 1.0 20160415_tlemma.maxent.gz
      $IT_LEMMA_MODELS'",

    $self->fl_agreement ? 'T2T::FormemeTLemmaAgreement fun='.$self->fl_agreement : (),
    'Util::DefinedAttr tnode=t_lemma,formeme message="after simple transfer"',
    #$self->domain eq 'IT' ? 'T2T::EN2ES::TrL_ITdomain' : (),
    'T2T::SetClauseNumber',
    'T2T::EN2EU::FixDefinitiveness',
    'T2T::EN2EU::FixThereIs',
    ;

    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Transfer::EN2EU - English-to-Basque TectoMT transfer (no analysis, no synthesis)

=head1 SYNOPSIS

 # From command line
 treex Scen::Transfer::EN2EU Write::Treex to=translated.treex.gz -- en_ttrees.treex.gz
 
 treex --dump_scenario Scen::Transfer::EN2EU

=head1 DESCRIPTION

This scenario expects input English text analyzed to t-trees in zone en_src.
The output (translated Basque t-trees) will be in zone eu_tst.

=head1 PARAMETERS

currently none

=head1 SEE ALSO

L<Treex::Scen::EN2EU> -- end-to-end translation scenario

=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
