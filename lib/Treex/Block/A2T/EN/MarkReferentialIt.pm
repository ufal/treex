package Treex::Block::A2T::EN::MarkReferentialIt;

use Moose;
use Moose::Util::TypeConstraints;

use Treex::Core::Common;

use Treex::Tool::ReferentialIt::Utils;
use Treex::Tool::ReferentialIt::Features;
use Treex::Tool::ML::MaxEnt::Model;
use Treex::Tool::ML::Classifier::RuleBased;

extends 'Treex::Core::Block';

subtype 'FeatArrayRef'
    => as 'ArrayRef[Str]';

coerce 'FeatArrayRef'
    => from 'Str'
        => via {my @arr = split /,/, $_; return \@arr;};

has 'resolver_type' => (
    is => 'ro',
    isa => enum( [qw/rules nada nada+rules/] ),
    required => 1,
    default => 'nada+rules',
);

has 'model_path' => (
    is       => 'ro',
    required => 1,
    isa      => 'Str',
    default  => 'data/models/refer_it/pcedt.sec00-10.nada+rules.compact.model',
    documentation => 'path to a trained model',
);

has 'threshold' => (
    is => 'ro',
    isa => 'Num',
    required => 1,
    default => 0.5,
);

# features not supported for the time being
#has 'features' => (
#    is => 'ro',
#    isa => 'FeatArrayRef',
#    coerce => 1,
#    default => '',
#);

# TODO this should be written against an interface (not an implementation)
has '_feat_extractor' => (
    is => 'ro',
    isa => 'Treex::Tool::ReferentialIt::Features',
    lazy => 1,
    builder => '_build_feat_extractor',
);

has '_classifier' => (
    is => 'ro',
    isa => 'Treex::Tool::ML::Classifier',
    lazy => 1,
    builder => '_build_classifier',
);

sub BUILD {
    my ($self) = @_;
    $self->_feat_extractor;
    $self->_classifier;
}

sub _build_feat_extractor {
    my ($self) = @_;

#    my $params = {};
#    if ($self->resolver_type eq 'nada') {
#        $params{feature_names} = ['nada_prob'];
#    }
#    else {
#        if (@{$self->features}) {
#            $params{feature_names} = $self->features;
#        }
#    }
#    return Treex::Tool::ReferentialIt::Features->new($params);
    my $all_features = $self->resolver_type eq "nada" ? 1 : 0;
    return Treex::Tool::ReferentialIt::Features->new({all_features => $all_features});
}

sub _build_classifier {
    my ($self) = @_;
    if ($self->resolver_type eq 'nada+rules') {
        my $model = Treex::Tool::ML::MaxEnt::Model->new();
        $model->load($self->model_path);
        return $model;
    }
    return Treex::Tool::ML::Classifier::RuleBased->new();
}

before 'process_zone' => sub {
    my ($self, $zone) = @_;
    
    $self->_feat_extractor->init_zone_features( $zone );
};

sub process_tnode {
    my ($self, $t_node) = @_;

    if (Treex::Tool::ReferentialIt::Utils::is_it($t_node)) {
#            print STDERR "IT_ID: $it_id " . $it_ref_probs{$it_id} . "\n";
#            print STDERR (join " ", @words) . "\n";
        $t_node->wild->{'referential'} = !$self->_is_non_refer($t_node) ? 1 : 0;
        
        #print STDERR "IT_REF=" . $t_node->wild->{'referential'} . ": " . $t_node->get_address . "\n";
    }
}

sub _is_non_refer {
    my ($self, $tnode) = @_;

    my $instance = $self->_feat_extractor->create_instance( $tnode );

    # TODO temporary solution
    if ($self->resolver_type eq 'nada') {
        $tnode->wild->{'referential_prob'} = $instance->{nada_prob};
        return $instance->{nada_prob} <= $self->threshold;
    }
    elsif ($self->resolver_type eq 'rules') {
        return $self->_classifier->predict( $instance );
    }
    else {
        return !$self->_classifier->predict( $instance );
    }
}

1;

# TODO POD
