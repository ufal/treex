package Treex::Scen::Coref;
use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;

subtype 'ModuleIndicator' => as 'HashRef';
coerce 'ModuleIndicator'
    => from 'Str'
    => via { my %h = map {$_ => 1} (split /,/, $_); \%h };

has 'language' => (
    is => 'ro',
    isa => 'Treex::Type::LangCode',
    required => 1,
    documentation => 'the language of the text to annotate with coreference',
);

has 'modules' => (
    is => 'ro',
    isa => 'ModuleIndicator',
    coerce => 1,
    default => 'all',
);

has 'model_type' => (
    is => 'ro',
    isa => enum([qw/pdt pcedt_bi pcedt_bi.with_en pcedt_bi.with_en.treex_cr pcedt_bi.with_en.base_cr/]),
    predicate => 'has_model_type',
);

has 'diagnostics' => (
    is => 'ro',
    isa => 'Bool',
    predicate => 'has_diagnostics',
);

has 'aligned_feats' => (
    is => 'ro',
    isa => 'Bool',
    default => 0,
);

sub get_scenario_string {
    my ($self) = @_;
    if ($self->language eq 'en') {
        return $self->get_en_scenario_string();
    }
    elsif ($self->language eq 'cs') {
        return $self->get_cs_scenario_string();
    }
    else {
        log_warn "Coreference resolution for the language ".$self->language." is not supported.";
        return 'Util::Eval document="1;"';
    }
}

sub prepare_params {
    my ($self) = @_;
    
    my $params = '';
    if ($self->has_model_type) {
        $params .= ' model_type='.$self->model_type;
    }
    if ($self->has_diagnostics) {
        $params .= ' diagnostics='.$self->diagnostics;
    }
    if ($self->aligned_feats) {
        $params .= ' aligned_feats='.$self->aligned_feats;
    }
    return $params;
}

sub get_cs_scenario_string {
    my ($self) = @_;

    my $params = $self->prepare_params;

    my $scen = join "\n",
    'Util::SetGlobal language=cs',
    $self->modules->{relpron} || $self->modules->{all} ? 'Coref::CS::RelPron::Resolve'.$params : '',
    $self->modules->{reflpron} || $self->modules->{all} ? 'Coref::CS::ReflPron::Resolve'.$params : '',
    $self->modules->{perspron} || $self->modules->{all} ? 'Coref::CS::PersPron::Resolve'.$params : '',
    ;

    return $scen;
}

sub get_en_scenario_string {
    my ($self) = @_;
    
    my $params = $self->prepare_params;

    my $scen = join "\n",
    'Util::SetGlobal language=en',
    $self->modules->{relpron}  || $self->modules->{all} ? 'Coref::EN::RelPron::Resolve'.$params : '',
    $self->modules->{cor}      || $self->modules->{all} ? 'Coref::EN::Cor::Resolve'.$params : '',
    $self->modules->{reflpron} || $self->modules->{all} ? 'Coref::EN::ReflPron::Resolve'.$params : '',
    $self->modules->{perspron} || $self->modules->{all} ? 'Coref::EN::PersPron::Resolve'.$params : '',
    ;

    return $scen;
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Scen::Coref - coreference resolution

=head1 SYNOPSIS

TODO

=head1 DESCRIPTION

TODO
Scenario for coreference resolution. 
One has to specify the language in the parameter C<language>.

=head1 PARAMETERS

TODO

=head2 language

Specify the language of the text for which coreference should be resolved.

=head1 AUTHORS

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
