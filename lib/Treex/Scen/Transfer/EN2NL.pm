package Treex::Scen::Transfer::EN2NL;
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

#has gazetteer => (
#     is => 'ro',
#     isa => 'Bool',
#     default => undef,
#     documentation => 'Use W2A::EN::GazeteerMatch A2T::ProjectGazeteerInfo T2T::EN2ES::TrGazeteerItems',
#);

has fl_agreement => (
     is => 'ro',
     isa => 'Str', #enum( [qw(0 Log-HM-P AM-Log-P ...)] ),
     default => '0',
     documentation => 'Use T2T::FormemeTLemmaAgreement with a specified function as parameter (Log-HM-P, AM-Log-P,...)',
);

sub BUILD {
    my ($self) = @_;
#    if (!defined $self->gazetteer){
#       $self->{gazetteer} = $self->domain eq 'IT' ? 1 : 0;
#    }
    if ($self->tm_adaptation eq 'auto'){
        $self->{tm_adaptation} = $self->domain eq 'IT' ? 'interpol' : 'no';
    }
    return;
}


sub get_scenario_string {
    my ($self) = @_;
    
    my $TM_DIR= 'data/models/translation/en2nl';
    
    my $IT_LEMMA_MODELS = '';
    my $IT_FORMEME_MODELS = '';
    if ($self->tm_adaptation eq 'interpol'){
        $IT_LEMMA_MODELS = "static 0.5 IT/20150725_batch1a-tlemma.static.gz\n      maxent 1.0 IT/20150725_batch1a-tlemma.maxent.gz";
        $IT_FORMEME_MODELS = "static 1.0 IT/20150725_batch1a-formeme.static.gz\n      maxent 0.5 IT/20150725_batch1a-formeme.maxent.gz";
    }
    
    my $scen = join "\n",
    'Util::SetGlobal language=nl selector=tst',
    'T2T::CopyTtree source_language=en source_selector=src',
    #$self->gazetteer ? 'T2T::EN2NL::TrGazeteerItems' : (),
    "T2T::TrFAddVariantsInterpol model_dir=$TM_DIR models='
      static 1.0 20150217_formeme.static.gz
      maxent 0.5 20150217_formeme.maxent.gz
      $IT_FORMEME_MODELS'",
    "T2T::TrLAddVariantsInterpol model_dir=$TM_DIR models='
      static 0.5 20150217_tlemma.static.gz
      maxent 1.0 20150217_tlemma.maxent.gz
      $IT_LEMMA_MODELS'",
    $self->fl_agreement ? 'T2T::FormemeTLemmaAgreement fun='.$self->fl_agreement : (),
    'Util::DefinedAttr tnode=t_lemma,formeme message="after simple transfer"',
    #$self->domain eq 'IT' ? 'T2T::EN2ES::TrL_ITdomain' : (),
    'T2T::SetClauseNumber',
    'T2T::EN2NL::TrLFPhrases',
    'T2T::EN2NL::FixCompounds',
    'T2T::EN2NL::AddNounGender',
    ;

    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Transfer::EN2NL - English-to-Dutch TectoMT transfer (no analysis, no synthesis)

=head1 SYNOPSIS

 # From command line
 treex Scen::Transfer::EN2NL Write::Treex to=translated.treex.gz -- en_ttrees.treex.gz
 
 treex --dump_scenario Scen::Transfer::EN2NL

=head1 DESCRIPTION

This scenario expects input English text analyzed to t-trees in zone en_src.
The output (translated Dutch t-trees) will be in zone nl_tst.

=head1 PARAMETERS

currently none

=head1 SEE ALSO

L<Treex::Scen::EN2NL> -- end-to-end translation scenario

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>
Ondřej Dušek <odusek@ufal.mff.cuni.cz>
Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
