package Treex::Tool::Triggers::FeatureFilter;

use Moose;
use Treex::Core::Common;

use YAML qw/LoadFile DumpFile/;

has 'config_file_path' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has '_config' => (
    is => 'ro',
    isa => 'Any',
    lazy => 1,
    builder => '_build_config',
);

sub BUILD {
    my ($self) = @_;
    $self->_config;
}

sub _build_config {
    my ($self) = @_;
    return LoadFile($self->config_file_path);
}

sub filter_feature {
    my ($self, $feat) = @_;

    # blacklist
    return undef if ($self->_is_blacklisted($feat));
   
    # feat transformations
    $feat = $self->_remove_bow_dist($feat);
    $feat = $self->_remove_weights($feat);
    return $feat;
}

sub _is_blacklisted {
    my ($self, $feat) = @_;

    my $blacklist = $self->_config->{blacklist};
    my @passed_patterns = grep {$feat =~ /$_/} @$blacklist;

    return (scalar @passed_patterns > 0);
}

sub _remove_bow_dist {
    my ($self, $feat) = @_;
    if ($self->_config->{no_bow_dist}) {
        $feat =~ s/^bow_[^=]+=/bow=/;
    }
    return $feat;
}

sub _remove_weights {
    my ($self, $feat) = @_;

    my $patterns = $self->_config->{no_weight};
    my @passed_patterns = grep {$feat =~ /$_/} @$patterns;

    return $feat if (!@passed_patterns);
    $feat =~ s/^([^:]*)::.*$/$1/;

    return $feat;
}

1;
