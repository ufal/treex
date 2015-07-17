package Treex::Scen::Transfer::ES2EN;
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
     isa => 'Bool',
     default => undef,
     documentation => 'T2T::ES2EN::TrGazeteerItems',
);


sub BUILD {
    my ($self) = @_;
    if ($self->domain eq 'IT' && !defined $self->gazetteer){
        $self->{gazetteer} = 1;
    }
    return;
}


sub get_scenario_string {
    my ($self) = @_;
    
    my $TM_DIR= 'data/models/translation/es2en';
    
    my $scen = join "\n",
    'Util::SetGlobal language=en selector=tst',
    'T2T::CopyTtree source_language=es source_selector=src',
    #$self->gazetteer eq 'IT' ? 'T2T::ES2EN::TrGazeteerItems' : (),
    "T2T::TrFAddVariants static_model=$TM_DIR/Pilot1_formeme.static.gz discr_model=$TM_DIR/Pilot1_formeme.maxent.gz",
    "T2T::TrLAddVariants static_model=$TM_DIR/Pilot1_tlemma.static.gz discr_model=$TM_DIR/Pilot1_tlemma.maxent.gz",
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

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
