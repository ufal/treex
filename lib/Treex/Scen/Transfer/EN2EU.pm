package Treex::Scen::Transfer::EN2EU;
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
     default => 0,
     documentation => 'Use T2T::EN2EU::TrGazeteerItems, default=0',
);

has fl_agreement => (
     is => 'ro',
     isa => enum( [qw(0 AM-P GM-P HM-P GM-Log-P HM-Log-P)] ),
     default => '0',
     documentation => 'Use T2T::FormemeTLemmaAgreement with a specified function as parameter',
);

sub BUILD {
    my ($self) = @_;
    return;
}


sub get_scenario_string {
    my ($self) = @_;
    
    my $TM_DIR= 'data/models/translation/en2eu';
    
    my $scen = join "\n",
    'Util::SetGlobal language=eu selector=tst',
    'T2T::CopyTtree source_language=en source_selector=src',
    #$self->gazetteer eq 'IT' ? 'T2T::EN2EU::TrGazeteerItems' : (),
    'T2T::EN2EU::TrLTryRules',

    $self->domain eq 'IT' ? 'T2T::TrLApplyTbxDictionary tbx=data/dictionaries/MicrosoftTermCollection.eu.tbx tbx_src_id=en-US tbx_trg_id=eu-es analysis=@data/dictionaries/MicrosoftTermCollection.eu.filelist analysis_src_language=en analysis_src_selector=src analysis_trg_language=eu analysis_trg_selector=trg src_blacklist=data/dictionaries/MicrosoftTermCollection.en-eu.src.blacklist.txt' : (),

    "T2T::TrFAddVariants static_model=$TM_DIR/Pilot1_formeme.static.gz discr_model=$TM_DIR/Pilot1_formeme.maxent.gz",
    "T2T::TrLAddVariants static_model=$TM_DIR/Pilot1_tlemma.static.gz discr_model=$TM_DIR/Pilot1_tlemma.maxent.gz",
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
