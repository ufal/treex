package Treex::Scen::Transfer::EU2EN;
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
     default => 0,
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
    return;
}


sub get_scenario_string {
    my ($self) = @_;
    
    my $TM_DIR= 'data/models/translation/eu2en';
    
    my $scen = join "\n",
    'Util::SetGlobal language=en selector=tst',
    'T2T::CopyTtree source_language=eu source_selector=src',
    $self->gazetteer ? 'T2T::TrGazeteerItems src_lang='.$self->src_lang : (),

    $self->domain eq 'IT' ? 'T2T::TrLApplyTbxDictionary tbx=data/dictionaries/MicrosoftTermCollection.eu.tbx tbx_src_id=eu-es tbx_trg_id=en-US analysis=@data/dictionaries/MicrosoftTermCollection.eu.filelist analysis_src_language=eu analysis_src_selector=trg analysis_trg_language=en analysis_trg_selector=src src_blacklist=data/dictionaries/MicrosoftTermCollection.eu-en.src.blacklist.txt trg_blacklist=data/dictionaries/MicrosoftTermCollection.eu-en.trg.blacklist.txt' : (),

    "T2T::TrFAddVariants static_model=$TM_DIR/Pilot1_formeme.static.gz discr_model=$TM_DIR/Pilot1_formeme.maxent.gz",
    "T2T::TrLAddVariants static_model=$TM_DIR/Pilot1_tlemma.static.gz discr_model=$TM_DIR/Pilot1_tlemma.maxent.gz",
    $self->fl_agreement ? 'T2T::FormemeTLemmaAgreement fun='.$self->fl_agreement : (),
    'Util::DefinedAttr tnode=t_lemma,formeme message="after simple transfer"',
    'T2T::SetClauseNumber',
    ;

    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Transfer::EU2EN - Basque-to-English TectoMT transfer (no analysis, no synthesis)

=head1 SYNOPSIS

 # From command line
 treex Scen::Transfer::EU2EN Write::Treex to=translated.treex.gz -- eu_ttrees.treex.gz
 
 treex --dump_scenario Scen::Transfer::EU2EN

=head1 DESCRIPTION

This scenario expects input Basque text analyzed to t-trees in zone eu_src.
The output (translated English t-trees) will be in zone en_tst.

=head1 PARAMETERS

currently none

=head1 SEE ALSO

L<Treex::Scen::EU2EN> -- end-to-end translation scenario

=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
