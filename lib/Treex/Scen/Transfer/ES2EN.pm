package Treex::Scen::Transfer::ES2EN;
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

has gazetteer => (
     is => 'ro',
     isa => 'Bool',
     default => undef,
     documentation => 'T2T::ES2EN::TrGazeteerItems',
);

has fl_agreement => (
     is => 'ro',
     isa => enum( [qw(0 AM-P GM-P HM-P GM-Log-P HM-Log-P)] ),
     default => '0',
     documentation => 'Use T2T::FormemeTLemmaAgreement with a specified function as parameter',
);

sub BUILD {
    my ($self) = @_;
    if (!defined $self->gazetteer){
        $self->{gazetteer} = $self->domain eq 'IT' ? 1 : 0;
    }
    if ($self->tm_adaptation eq 'auto'){
        $self->{tm_adaptation} = $self->domain eq 'IT' ? 'interpol' : 'no';
    }
    return;
}


sub get_scenario_string {
    my ($self) = @_;
    
    my $TM_DIR= 'data/models/translation/es2en';

    my $IT_LEMMA_MODELS = '';
    my $IT_FORMEME_MODELS = '';
    if ($self->tm_adaptation eq 'interpol'){
        $IT_LEMMA_MODELS = "static 0.5 IT/20150728_batch1q-tlemma.static.gz\n      maxent 1.0 IT/20150728_batch1q-tlemma.maxent.gz";
        $IT_FORMEME_MODELS = "static 1.0 IT/20150728_batch1q-formeme.static.gz\n      maxent 0.5 IT/20150728_batch1q-formeme.maxent.gz";
    }
    
    my $scen = join "\n",
    'Util::SetGlobal language=en selector=tst',
    'T2T::CopyTtree source_language=es source_selector=src',
    #$self->gazetteer eq 'IT' ? 'T2T::ES2EN::TrGazeteerItems' : (),
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
    'T2T::SetClauseNumber',
    ;

    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Transfer::ES2EN - Spanish-to-English TectoMT transfer (no analysis, no synthesis)

=head1 SYNOPSIS

 # From command line
 treex Scen::Transfer::ES2EN Write::Treex to=translated.treex.gz -- es_ttrees.treex.gz
 
 treex --dump_scenario Scen::Transfer::ES2EN

=head1 DESCRIPTION

This scenario expects input Spanish text analyzed to t-trees in zone es_src.
The output (translated English t-trees) will be in zone en_tst.

=head1 PARAMETERS

currently none

=head1 SEE ALSO

L<Treex::Scen::ES2EN> -- end-to-end translation scenario

=head1 AUTHORS

Gorka Labaka <gorka.labaka@ehu.eus>
Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
