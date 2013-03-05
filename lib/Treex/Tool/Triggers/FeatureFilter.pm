package Treex::Tool::Triggers::FeatureFilter;

use Moose;
use Treex::Core::Common;
use File::Slurp;
use Compress::Zlib;
use List::MoreUtils qw/uniq/;

use YAML qw/LoadFile DumpFile/;

has 'config_file_path' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has 'testing' => (
    isa => 'Bool',
    is => 'ro',
    default => 0,
);

has '_config' => (
    is => 'ro',
    isa => 'Any',
    lazy => 1,
    builder => '_build_config',
);

has '_mi_bi' => (
    is => 'ro',
    isa => 'Maybe[HashRef[HashRef[ArrayRef]]]',
    lazy => 1,
    builder => '_build_mi_bi',
);

sub BUILD {
    my ($self) = @_;
    $self->_config;
    if (!$self->testing) {
        $self->_mi_bi;
    }
}

sub _build_config {
    my ($self) = @_;
    return LoadFile($self->config_file_path);
}

sub _build_mi_bi {
    my ($self) = @_;
    
    my $mi_bi_path = $self->_config->{mi_bi}{path};
    return undef if (!defined $mi_bi_path);
   
    log_info "Loading the mi_bi model from " . $mi_bi_path . "...";
    my $buffer = Compress::Zlib::memGunzip(read_file( $mi_bi_path )) ;
    my $mi_bi = Storable::thaw($buffer) or log_fatal $!;
    log_info "mi_bi model loaded.";
    return $mi_bi;
}

sub filter_features {
    my ($self, $feats, $en_lemma, $cs_lemma) = @_;

    # filtering
    my @filtered_feats = grep {defined $_} map {$self->_process_single_feature($_, $en_lemma, $cs_lemma)} (@$feats);
    # duplicate must be removed
    my @uniq_feats = uniq @filtered_feats;

    return @uniq_feats;
}

sub _process_single_feature {
    my ($self, $feat, $en_lemma, $cs_lemma) = @_;

    # feat filtering only during a training stage
    if (!$self->testing) {
        # blacklist
        return undef if ($self->_is_blacklisted($feat));

        # pwmi filtering
        #return undef if ($self->_filter_bow_by_pwmi($feat, $en_lemma, $cs_lemma));
        # mi filtering
        return undef if ($self->_filter_by_mi_bi($feat, $en_lemma));
    }
   
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

sub _filter_bow_by_pwmi {
    my ($self, $feat, $en_lemma, $cs_lemma) = @_;

    my $en_pwmi_path = $self->_config->{pwmi_en}{path};
    my $en_pwmi_ratio = $self->_config->{pwmi_en}{ratio};

    return 0 if (!defined $en_pwmi_path);

    my $feat_clear = $feat;
    $feat_clear =~ s/^bow_[^=]+=(.*)::.*$/$1/;

    my $buffer = Compress::Zlib::memGunzip(read_file( $en_pwmi_path )) ;
    my $en_pwmi = Storable::thaw($buffer) or log_fatal $!;

    return ($en_pwmi->{$en_lemma}{$feat_clear}->[1] <= $en_pwmi_ratio);
}

sub _filter_by_mi_bi {
    my ($self, $feat, $en_lemma, $cs_lemma) = @_;

    #return 0 if ($feat !~ /^bow_/);

    my $mi_bi = $self->_mi_bi;
    return 0 if (!defined $mi_bi);
    return 0 if (!defined $mi_bi->{$en_lemma});
    
    my $mi_bi_ratio = $self->_config->{mi_bi}{ratio};

    #my $aux_str = $feat;
    my $feat_clear = $feat;
    $feat_clear =~ s/^(.*)(::.+)?$/$1/;
    #$aux_str .= " $feat_clear";
    # bow features in mi_bi file are for the time being stripped off the additional info affixes
    if (!defined $mi_bi->{$en_lemma}{$feat_clear}) {
        $feat_clear =~ s/^bow_[^=]+=(.*)$/$1/;
    #    $aux_str .= " $feat_clear";
    #    print STDERR "VER: $aux_str\n";
    }

    return 1 if (!defined $mi_bi->{$en_lemma}{$feat_clear});
    return ($mi_bi->{$en_lemma}{$feat_clear}->[1] <= $mi_bi_ratio);
}

1;
