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

sub get_cs_scenario_string {
    my ($self) = @_;

    my $scen = join "\n",
    'Util::Eval document="1;"',
    $self->modules->{relpron} || $self->modules->{all} ? 'Coref::CS::RelPron::Resolve' : '',
    $self->modules->{reflpron} || $self->modules->{all} ? 'Coref::CS::ReflPron::Resolve' : '',
    $self->modules->{perspron} || $self->modules->{all} ? 'Coref::CS::PersPron::Resolve' : '',
    ;

    return $scen;
}

sub get_en_scenario_string {
    my ($self) = @_;

    my $scen = join "\n",
    'Util::Eval document="1;"',
    $self->modules->{relpron} || $self->modules->{all} ? 'Coref::EN::RelPron::Resolve' : '',
    $self->modules->{reflpron} || $self->modules->{all} ? 'Coref::EN::ReflPron::Resolve' : '',
    $self->modules->{perspron} || $self->modules->{all} ? 'Coref::EN::PersPron::Resolve' : '',
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
