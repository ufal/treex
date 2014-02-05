package Treex::Tool::Flect::FlectBlock;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

use Treex::Tool::Flect::Base;
use Treex::Core::Resource;
use YAML::Tiny;
use autodie;

with 'Treex::Block::Write::AttributeParameterized';

has '+attributes' => ( builder => '_build_attributes', lazy_build => 1 );

has _flect => ( is => 'rw', isa => 'Maybe[Treex::Tool::Flect::Base]' );

has model_file => ( is => 'ro', isa => 'Str', required => 1 );

has features_file => ( is => 'ro', isa => 'Str', required => 1 );

has _features_file_data => ( is => 'ro', isa => 'HashRef', builder => '_build_features_file_data', lazy_build => 1 );

sub _build_attributes {
    my ($self) = @_;
    return $self->_features_file_data->{plain_sources};
}

sub _build_features_file_data {
    my ($self) = @_;
    return {} if ( not $self->features_file );

    my $cfg = YAML::Tiny->read( Treex::Core::Resource::require_file_from_share( $self->features_file ) );
    $cfg = $cfg->[0];

    my $feats = {
        additional    => $cfg->{additional_features},
        plain_labels  => [ map { $_->{label} } @{ $cfg->{features} } ],
        plain_sources => [ map { $_->{source} } @{ $cfg->{features} } ],
    };
    return $feats;
}

sub process_start {

    my ($self) = @_;

    my $model = Treex::Core::Resource::require_file_from_share( $self->model_file );

    my $flect = Treex::Tool::Flect::Base->new(
        {
            model_file          => $model,
            features            => $self->_features_file_data->{plain_labels},
            additional_features => $self->_features_file_data->{additional},
        }
    );
    $self->_set_flect($flect);
}

sub inflect_nodes {
    my ( $self, @nodes ) = @_;

    my @data = map { join( '|', _escape( $self->_get_info_list($_) ) ) } @nodes;

    my $forms = $self->_flect->inflect_sentence( \@data );
    return @$forms;
}

sub _escape {
    my ($list) = @_;
    return map { $_ = '' if ( not defined $_ ); $_ =~ s/'/\\'/g; $_ } @$list;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Tool::Flect::FlectBlock

=head1 DESCRIPTION

A generic block that uses Flect L<http://ufal.mff.cuni.cz/flect> to generate word forms for nodes.

This requires a trained Flect model and features list in YAML format, which are passed to the
class as C<model_file> and C<features_file> properties.

=head1 AUTHORS 

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
