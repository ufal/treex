package Treex::Block::A2T::EN::MarkReferentialIt;

use Moose;

extends 'Treex::Core::Block';

has 'use_nada' => (
    is => 'ro',
    isa => 'Bool',
    required => 1,
    default => 1,
);

has 'threshold' => (
    is => 'ro',
    isa => 'Num',
    required => 1,
    default => 0.5,
);

has '_use_rules' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

has 'rules' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
    default => '',
);

has '_rules_hash' => (
    is => 'ro',
    isa => 'HashRef[Bool]',
    required => 1,
    lazy => 1,
    builder => '_build_rules_hash',
);

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
    $self->_rules_hash;
    $self->_feat_extractor;
    $self->_classifier;
    use Data::Dumper;
    print Dumper($self->_rules_hash);
}

sub _build_rules_hash {
    my ($self) = @_;

    my %rules = map {$_ => 1} (split /,/, $self->rules);
    $self->_set_use_rules(1) if (keys %rules > 0);
    return \%rules;
}

sub _build_feat_extractor {
    my ($self) = @_;
    
    my @feats = ();
    if ($self->use_nada && $self->_use_rules) {
        @feats = (keys %{$self->_rules_hash}, 'nada_prob');
    }
    elsif ($self->_use_rules) {
        @feats = keys %{$self->_rules_hash};
    }
    elsif ($self->use_nada) {
        @feats = ('nada_prob');
    }

    return Treex::Tool::ReferentialIt::Features->new(
        {feature_names => \@feats});
}

sub _build_classifier {
    my ($self) = @_;
    if ($self->_use_rules && $self->use_nada) {
        return Treex::Tool::ML::Classifier::MaxEnt->new({model_path => #TODO
        });
    }
    return Treex::Tool::ML::Classifier::RuleBased->new();
}

before 'process_zone' => sub {
    my ($self, $zone) = @_;
    
    $self->_feat_extractor->init_zone_features( $zone );
};

sub process_tnode {
    my ($self, $t_node) = @_;

    my $is_it = grep {$_->lemma eq 'it'} $t_node->get_anodes;
    if ($is_it) {
#            print STDERR "IT_ID: $it_id " . $it_ref_probs{$it_id} . "\n";
#            print STDERR (join " ", @words) . "\n";
        $t_node->wild->{'referential'} = !$self->_is_non_refer($t_node) ? 1 : 0;
    }
}

sub _is_non_refer {
    my ($self, $tnode) = @_;

    my $instance = $self->_feat_extractor->create_instance( $tnode );

    # TODO temporary solution
    if (!$self->_use_rules && $self->use_nada) {
        $t_node->wild->{'referential_prob'} = $instance->{nada_prob};
        return $instance->{nada_prob} <= $self->threshold;
    }
    else {
        return $self->_classifier->predict( $instance );
    }
}

1;

# TODO POD
