package Treex::Scen::Coref;
use Moose;
use Moose::Util::TypeConstraints;
use Treex::Core::Common;
use Data::Printer;

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

has 'models' => (
    is => 'ro',
    isa => 'Str',
    predicate => 'has_models',
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

    my $lang = $self->language;
    
    # so far, only Czech and English supported
    if ($lang !~ /^(en|cs)$/) {
        log_warn "Coreference resolution for the language ".$lang." is not supported.";
        return 'Util::Eval document="1;"';
    }

    my $lang_CAP = uc $lang;
    my $common_params = $self->prepare_common_params;

    my $scen = join "\n",
    'Util::SetGlobal language='.$lang,
    $self->modules->{cor}       || $self->modules->{all} ? sprintf 'Coref::%s::Cor::Resolve %s %s',      $lang_CAP, $common_params, $self->prepare_anaphtype_params("cor") : '',
    $self->modules->{relpron}   || $self->modules->{all} ? sprintf 'Coref::%s::RelPron::Resolve %s %s',  $lang_CAP, $common_params, $self->prepare_anaphtype_params("relpron") : '',
    $self->modules->{reflpron}  || $self->modules->{all} ? sprintf 'Coref::%s::ReflPron::Resolve %s %s', $lang_CAP, $common_params, $self->prepare_anaphtype_params("reflpron") : '',
    $self->modules->{perspron}  || $self->modules->{all} ? sprintf 'Coref::%s::PersPron::Resolve %s %s', $lang_CAP, $common_params, $self->prepare_anaphtype_params("#perspron.no_refl") : '',
    ;

    return $scen;
}

sub prepare_common_params {
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

sub prepare_anaphtype_params {
    my ($self, $type) = @_;

    my $params = '';
    if ($self->has_models) {
        my @paths = glob $self->models;
        my @filtered_paths = grep {$_ =~ /([\/.]|^)\Q$type\E([\/.]|$)/} @paths;
        if (@filtered_paths) {
            log_warn "[Treex::Scen::Coref] Too many models for an anaphor type $type. Taking the first one: ".$filtered_paths[0] if (@filtered_paths > 1);
            $params .= ' model_path='.$filtered_paths[0];
        }
    }
    return $params;
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
