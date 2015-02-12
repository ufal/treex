package Treex::Tool::TranslationModel::ML::Learner;

use Moose;

use Treex::Core::Common;
use Treex::Tool::TranslationModel::ML::Model;
use Treex::Tool::ML::Factory;

with 'Treex::Tool::TranslationModel::Learner';

binmode STDERR, ":encoding(utf8)";

############ ARGUMENTS ###############

has 'learner_type' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has 'params' => (
    is => 'ro',
    isa => 'HashRef',
    default => sub {{}},
);

has 'feature_cut' => (
    is => 'ro',
    isa => 'Int',
);

# TODO figure out how to include cutting on weights
#has 'feat_weight_cut' => (
#    is => 'ro',
#    isa => 'Num',
#);

#has 'smooth_sigma' => (
#    is => 'ro',
#    isa => 'Num',
#    default => 0.99,
#);

############ MODEL #############

has '_model' => (
    is => 'ro', 
    isa => 'Treex::Tool::TranslationModel::ML::Model',
    builder => '_build_model',
    lazy => 1,
);

has '_submodel_learner_factory' => (
    isa => 'Treex::Tool::ML::Factory',
    is => 'ro',
    default => sub { Treex::Tool::ML::Factory->new(); }, 
);

has '_submodel_learner' => (
    is => 'ro',
    isa => 'Treex::Tool::ML::Learner',
    builder => '_build_submodel_learner',
    lazy => 1,
);

########### BUILDERS ############

sub BUILD {
    my ($self) = @_;
    $self->_submodel_learner;
    $self->_model;
}

sub _build_model {
    my ($self) = @_;
    return Treex::Tool::TranslationModel::ML::Model->new({model_type => $self->learner_type});
}

sub _build_submodel_learner {
    my ($self) = @_;
    return $self->_submodel_learner_factory->create_learner(
        $self->learner_type, $self->params);
    #return Treex::Tool::ML::MaxEnt::Learner->new(
    #    smoother => { type => 'gaussian', sigma => $self->smooth_sigma }
    #);
}

around 'prune_instances' => sub {
    my ($orig, $self, @instances) = @_;
    @instances = $self->$orig(@instances);
    my %aux_hash = map {$_->{label} => 1} @instances;
    my $label_num = scalar keys %aux_hash;
    
    # no reason to learn a model for just one class
    if ($label_num <= 1) {
        return ();
    }
    return @instances;
};

sub _process_instances {
    my ($self, @instances) = @_;
    foreach my $instance (@instances) {
        if (scalar(@{$instance->{features}}) == 0) {
            $instance->{features} = [ 'dummy_feat' ];
        }
        $self->_submodel_learner->see( $instance->{features}, $instance->{label} );
    }
    if ($self->feature_cut) {
        print STDERR "Cutting counts...\n";
        $self->_submodel_learner->cut_features($self->feature_cut);
    }
    my $submodel = $self->_submodel_learner->learn;
    
    # TODO figure out how to include cutting on weights
    #if (defined $self->feat_weight_cut) {
    #    print STDERR "Cutting weights...\n";
    #    $submodel->cut_weights($self->feat_weight_cut);
    #}
    
    $self->_submodel_learner->forget_all;
    return $submodel;
}

1;

__END__


=head1 NAME

TranslationModel::ML::Learner



=head1 DESCRIPTION


=head1 COPYRIGHT

Copyright 2009-2012 Zdenek Zabokrtsky, Michal Novak.
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
