package Treex::Tool::FeatureExtract;

use Moose;
use Treex::Core::Common;
use Moose::Util::TypeConstraints;
use Treex::Core::Resource;

with 'Treex::Block::Write::AttributeParameterized';

use YAML::Tiny;
use autodie;

has '+attributes' => ( builder => '_build_attributes', lazy_build => 1 );

has '+modifier_config' => ( builder => '_build_modifier_config', lazy_build => 1 );

has 'features_file' => ( is => 'ro', isa => 'Str', required => 1 );

has '_features_file_data' => ( is => 'ro', isa => 'HashRef', builder => '_build_features_file_data', lazy_build => 1 );

# Override output attribute names and types
has 'output_attrib_names' => ( is => 'ro', isa => 'HashRef', builder => '_build_output_attrib_names', lazy_build => 1 );

has 'output_attrib_types' => ( is => 'ro', isa => 'ArrayRef', lazy_build => 1, builder => '_build_output_attrib_types' );

# TODO To be fixed and removed. This is for caching due to AttributeParameterized's behavior 
# (need to keep track of nodes' zones and clear cache if zone changes)
has '_last_processed_zone' => ( is => 'rw', default => 0 );

sub _build_attributes {
    my ($self) = @_;
    return $self->_features_file_data->{sources};
}

# Take the output attribute names from the config file, if none are given explicitly
sub _build_output_attrib_names {
    my ($self) = @_;
    return $self->_features_file_data->{labels} // {};
}

sub _build_output_attrib_types {
    my ($self) = @_;
    return [ map { split /\|/, $_ } @{ $self->_features_file_data->{types} } ];
}

# Take the attribute modifier configuration from the config file, if none is given explicitly
sub _build_modifier_config {
    my ($self) = @_;
    return _parse_modifier_config( $self->_features_file_data->{modifier_config} );
}

sub _build_features_file_data {
    my ($self) = @_;
    return {} if ( not $self->features_file );
    
    my $feat_file = $self->features_file;
    if ( !-f $feat_file ) {
        $feat_file = Treex::Core::Resource::require_file_from_share( $feat_file, ref($self) );
    }
    if ( !-f $feat_file ) {
        log_fatal 'File ' . $feat_file . ' does not exist.';
    }
    
    my $cfg = YAML::Tiny->read( $feat_file );
    $cfg = $cfg->[0];

    my $feats = {
        labels => {
            map {
                $_->{source} => $_->{label} ? [ split( /[\s,]+/, $_->{label} ) ] : undef
                } @{ $cfg->{features} }
        },
        sources => [ map { $_->{source} } @{ $cfg->{features} } ],
        types => [
            map {
                my $srcs = $_->{label} // $_->{source};
                $srcs =~ s/(\S+)/STRING/g;
                my $val = $_->{type} // $srcs;
                chomp $val;
                $val =~ s/\s+/\|/g;
                $val
                } @{ $cfg->{features} }
        ],
        modifier_config => $cfg->{modifier_config},
    };
    return $feats;
}

# From ArffWriting
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

# Return features of a node in the VowpalWabbit format
sub get_features_vw {
    my ( $self, $node ) = @_;
    
    if ( $node->get_zone() != $self->_last_processed_zone ){
        $self->_clear_cache();
        $self->_set_last_processed_zone( $node->get_zone );
    }

    # get all preset features of my node
    my $info = $self->_get_info_hash($node);

    # order them according to the order defined in the config file, convert to name=value or name:value
    my @feats = ();
    for ( my $i = 0; $i < @{ $self->_output_attrib }; ++$i ) {
        my ( $name, $type ) = ( $self->_output_attrib->[$i], $self->output_attrib_types->[$i] );
        if ( $type =~ /^NUMERIC$/i ) {
            push @feats, $name . '==' . ($info->{$name} // 0);    # avoid escaping here (will be converted to `:')
        }
        else {
            push @feats, $name . '=' . ($info->{$name} // '');
        }
    }

    # skip irrelevant features

    # modify set features
    @feats = map {
        if ( $_ =~ /^\*/ ) {
            my $set_feat = $_;
            my ( $name, $val_set ) = split /=/, $set_feat, 2;
            my @subset_feats = map { $name . '⊆' . $_ } split / /, $val_set;
            ( $set_feat, @subset_feats );
        }
        else {
            $_;
        }
    } @feats;

    # escape features
    @feats = map { _vw_escape($_) } @feats;
    return \@feats;
}

sub _vw_escape {
    my ($str) = @_;
    $str = '' if ( not defined $str );
    $str =~ s/\|/&pipe;/g;
    $str =~ s/\t/&tab;/g;
    $str =~ s/ /_/g;
    $str =~ s/:/&colon;/g;
    $str =~ s/==([-0-9.e]+)$/:$1/;    # fix numeric `='
    return $str;
}


# Only to accommodate to AttributeParameterized role
# TODO: fix this; however, cache cleaning is really needed (after each document)
sub process_zone {}

# Also, only to accomodate to AttributeParameterized role
sub BUILD {
}

sub _clear_cache {
    my ($self) = @_;
    $self->_set_cache( {} );
    return;
}

1;
