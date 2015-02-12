package Treex::Tool::TranslationModel::Learner;

use Moose::Role;

use Treex::Core::Common;
use List::Util qw/sum/;

requires '_process_instances';

############ ARGUMENTS ###############

has 'min_instances' => (
    is => 'ro',
    isa => 'Int',
    default => 0,
);
has 'max_instances' => (
    is => 'ro',
    isa => 'Int',
    # 0 means no upper limit
    default => 0,
);
has 'min_per_class' => (
    is => 'ro',
    isa => 'Int',
    default => 0,
);
has 'class_coverage' => (
    is => 'ro',
    isa => 'Num',
    documentation => 'the maximum proportion of instances sorted by its class frequencies',
);

# one do not have to store the unprocessed instances if these precounted
# stats are supplied
has 'input_counts' => (
    is => 'ro',
    isa => 'HashRef[Int]',
);

########### AUX PRIVATE VARIABLES ############

has '_unprocessed_instances' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
);

has '_current_input_label' => (
    is => 'rw',
    isa => 'Str',
);


########### PUBLIC METHODS ###########

before 'BUILD' => sub {
    my ($self) = @_;
    srand(1);
};

sub get_model {
    my ( $self ) = @_;
    $self->_finish_submodel;
    return $self->_model;
}

sub reset {
    my ($self) = @_;
#        delete $self->counts;
    return;
}

sub see {
    my ( $self, $input_label, $output_label, $features, $count ) = @_;
        #print STDERR ":$input_label:" . $self->_current_input_label . ":\n";
    if (!defined $self->_current_input_label) {
        $self->_current_input_label($input_label);
    }
    if ($input_label ne $self->_current_input_label) {
        $self->_finish_submodel;
        
        $self->_unprocessed_instances([]);
        $self->_current_input_label($input_label);
    }

    my $add_instance = 1;
    if (defined $self->input_counts && $self->max_instances && ($self->max_instances < $self->input_counts->{$input_label})) {
        my $accepting_prob = $self->max_instances / $self->input_counts->{$input_label};
        $add_instance = rand() < $accepting_prob ? 1 : 0;
    }
    if ($add_instance) {
        push @{$self->_unprocessed_instances},
            { label=>$output_label, features=>$features, count=>$count };
    }
}

sub prune_instances {
    my ($self, @instances) = @_;
    
    # do not learn if min_instances is not reached
    my $instance_num = sum( map {$_->{count} || 1} @instances );
    if ($self->min_instances > $instance_num) {
        return ();
    }
    
    my %class_counts;
    $class_counts{$_}++ foreach (map {$_->{label}} @instances);
    
    # filter out non-frequent classes by coverage
    if (defined $self->class_coverage) {
        my $cum_ratio_class = _get_class_by_coverage($self->class_coverage, \%class_counts, $instance_num);
        @instances = grep {$class_counts{$_->{label}} >= $class_counts{$cum_ratio_class}} @instances;
    }
    # filter out non-frequent classes by an exact count
    if ($self->min_per_class > 0) {
        @instances = grep {$class_counts{$_->{label}} >= $self->min_per_class} @instances;
    }
    
    # learn from a subsample if max_instances is set
    if (!defined $self->input_counts && $self->max_instances && ($self->max_instances < scalar @instances)) {
        my $accepting_prob = $self->max_instances / scalar @instances;
        return grep {rand() < $accepting_prob} @instances;
    }
    return @instances;
}

sub _get_class_by_coverage {
    my ($coverage, $counts, $total) = @_;

    my @sorted = sort {$counts->{$b} <=> $counts->{$a}} keys %$counts;
    my $cum_ratio_now = 0;
    foreach (@sorted) {
        my $ratio = $counts->{$_}/$total;
        $cum_ratio_now += $ratio;
        if ($cum_ratio_now >= $coverage) {
            return $_;
        }
    }
    return $sorted[-1];
}

########### PRIVATE METHODS ###########

sub _finish_submodel {
    my ( $self ) = @_;

    my $input_label = $self->_current_input_label;
    my @instances = $self->prune_instances(@{$self->_unprocessed_instances});

    return if (!@instances);

    my $instance_num = defined $self->input_counts ? $self->input_counts->{$input_label} : scalar @{$self->_unprocessed_instances};
    print STDERR "$input_label\tused instances: " . scalar @instances . " from " . $instance_num . "\n";

    my $submodel = $self->_process_instances( @instances );
    $self->_model->add_submodel($input_label, $submodel);

    return;
}

1;
