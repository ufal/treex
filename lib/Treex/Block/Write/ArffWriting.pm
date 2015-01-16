package Treex::Block::Write::ArffWriting;

use Moose::Role;
use Moose::Util::TypeConstraints;
use MooseX::Role::AttributeOverride;
use Treex::Core::Log;
use Treex::Tool::IO::Arff;
use YAML::Tiny;
use autodie;

with 'Treex::Block::Write::AttributeParameterized';

#
# DATA
#

# ARFF data file structure as it's set in Treex::Tool::IO::Arff
has '_arff_writer' => ( is => 'ro', builder => '_init_arff_writer', lazy_build => 1 );

# Allow building attributes and modifier_config from the configuration file
has_plus 'attributes'      => ( builder => '_build_attributes',      lazy_build => 1 );
has_plus 'modifier_config' => ( builder => '_build_modifier_config', lazy_build => 1 );

# Override the default data type settings
subtype 'Treex::Block::Write::ArffWriting::ForceTypes' => as 'HashRef';
coerce 'Treex::Block::Write::ArffWriting::ForceTypes' =>
    from 'Str' => via { _parse_hashref($_) };

has 'force_types' => (
    is         => 'ro',
    isa        => 'Treex::Block::Write::ArffWriting::ForceTypes',
    builder    => '_build_force_types',
    coerce     => 1,
    lazy_build => 1
);

# Override output attribute names
subtype 'Treex::Block::Write::ArffWriting::OutputAttribNames' => as 'HashRef';
coerce 'Treex::Block::Write::ArffWriting::OutputAttribNames' =>
    from 'Str' => via { _parse_hashref($_) };

has 'output_attrib_names' => (
    is         => 'ro',
    isa        => 'Treex::Block::Write::ArffWriting::OutputAttribNames',
    builder    => '_build_output_attrib_names',
    coerce     => 1,
    lazy_build => 1
);

# Configuration file name (YAML with attribute sources, labels and types + modifier configuration)
has 'config_file' => ( isa => 'Str', is => 'ro' );

# Data read from the configuration file, to be propagated to other attributes
has '_config_file_data' => ( isa => 'HashRef', is => 'rw', builder => '_build_config_file_data', lazy_build => 1 );

# Were the ARFF file headers already printed ?
has '_headers_printed' => ( is => 'ro', isa => 'Bool', writer => '_set_headers_printed', default => 0 );


#
# METHODS
#

# Apply all attribute name overrides as specified in output_attrib_names
around '_set_output_attrib' => sub {

    my ( $orig_method, $self, $output_attrib ) = @_;

    my $over      = $self->output_attrib_names;
    my $orig_attr = $self->_attrib_io;
    my %ot        = ();

    # build an override table: original name => overridden name
    foreach my $in_attr ( keys %{$orig_attr} ) {
        foreach my $i ( 0 .. @{ $orig_attr->{$in_attr} } - 1 ) {
            $ot{ $orig_attr->{$in_attr}->[$i] } = $over->{$in_attr} ? $over->{$in_attr}->[$i] : $orig_attr->{$in_attr}->[$i];
        }
    }

    # apply the override table
    $output_attrib = [ map { $ot{$_} } @{$output_attrib} ];

    $self->$orig_method($output_attrib);
    return;
};

# YAML configuration file reader
sub _build_config_file_data {

    my ($self) = @_;
    my $file_name = $self->config_file;
    return {} if ( !$file_name );

    my $cfg = YAML::Tiny->read($file_name);
    log_fatal( 'Cannot read configuration file ' . $file_name ) if ( !$cfg );

    $cfg = $cfg->[0];
    if (!defined($cfg->{attributes}) and defined($cfg->{features})){
        $cfg->{attributes} = $cfg->{features}; # accepting both 'features' and 'attributes' key
    }
    my @sources = map { $_->{source} } @{ $cfg->{attributes} };
    my %labels  = map { $_->{source} => $_->{label} ? [ split( /[\s,]+/, $_->{label} ) ] : undef } @{ $cfg->{attributes} };
    my %types   = map { $_->{source} => $_->{type} ? [ split( /[\s,]+/, $_->{type} ) ] : undef } @{ $cfg->{attributes} };

    return {
        sources         => \@sources,
        labels          => \%labels,
        types           => \%types,
        modifier_config => $cfg->{modifier_config}
    };
}

# Take the output attribute names from the config file, if none are given explicitly
sub _build_output_attrib_names {
    my ($self) = @_;
    return $self->_config_file_data->{labels} // {};
}

# Take the attribute type overrides from the config file, if none are given explicitly
sub _build_force_types {
    my ($self) = @_;
    return $self->_config_file_data->{types} // {};
}

# Take the attribute list from the config file, if none are given explicitly
sub _build_attributes {
    my ($self) = @_;
    return $self->_config_file_data->{sources};
}

# Take the attribute modifier configuration from the config file, if none is given explicitly
sub _build_modifier_config {
    my ($self) = @_;
    return _parse_modifier_config( $self->_config_file_data->{modifier_config} );
}

# Initialize the ARFF output module
sub _init_arff_writer {

    my ($self) = @_;
    my $arff = Treex::Tool::IO::Arff->new();

    $arff->relation->{relation_name} = 'RELATION';
    $arff->relation->{relation_name} = $self->to if ( $self->does('to') && ( $self->to || '' ) !~ /^[\.-]?$/ );

    push( @{ $arff->relation->{attributes} }, { attribute_name => 'sent_id', attribute_type => 'STRING' } );
    push( @{ $arff->relation->{attributes} }, { attribute_name => 'word_id', attribute_type => 'NUMERIC' } );

    my $j = 0;

    foreach my $attr ( @{ $self->attributes } ) {

        foreach my $i ( 0 .. @{ $self->_attrib_io->{$attr} } - 1 ) {

            my $attr_entry = {
                'attribute_name' => $self->_output_attrib->[ $j++ ],
                'attribute_type' => ( $self->force_types->{$attr} ? $self->force_types->{$attr}->[$i] : undef )
            };

            push @{ $arff->relation->{attributes} }, $attr_entry;
        }
    }

    return $arff;
}

# Handle one node with the given sentence ID and word ID
sub _push_node_to_output {

    my ( $self, $node, $sent_id, $word_id ) = @_;

    my $info = $self->_get_info_hash($node);

    $info->{sent_id} = $sent_id;
    $info->{sent_id} =~ s/[-_]root$//;
    $info->{word_id} = $word_id;

    push( @{ $self->_arff_writer->relation->{records} }, $info );
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Write::ArffWriting

=head1 DESCRIPTION

A Moose role for blocks writing L<ARFF|http://www.cs.waikato.ac.nz/~ml/weka/arff.html> data
(used by the L<WEKA|http://www.cs.waikato.ac.nz/ml/weka/> machine learning environment). 

See L<Treex::Block::Write::Arff> for usage and more information.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
