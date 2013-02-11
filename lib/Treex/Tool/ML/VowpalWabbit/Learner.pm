package Treex::Tool::ML::VowpalWabbit::Learner;

use Moose;

use Treex::Core::Common;

use VowpalWabbit;
use Treex::Tool::ML::VowpalWabbit::Util;
#use Treex::Tool::ML::VowpalWabbit::Model;
use Treex::Tool::ML::Classifier::Linear;
use Treex::Tool::Compress::Index;

use List::Util qw(shuffle);

use IO::Zlib;
use File::Slurp;

with 'Treex::Tool::ML::Learner';

has 'passes' => (
    is => 'ro',
    isa => 'Int',
    required => 1,
    default => 5,
);

# the level of verbosity
# 0 = no info prints
# 1 = just info prints of Perl wrapper
# 2 = all info prints including those from the C++ library 
has 'verbose' => (
    is => 'ro',
    isa => enum([0, 1, 2]),
    default => 0,
    required => 1,
);

has '_unprocessed_instances' => (
    is  => 'ro',
    isa => 'ArrayRef[HashRef]',
    default => sub {[]},
    writer => '_set_instances',
);

has '_current_index' => (
    is => 'ro',
    isa => 'Treex::Tool::Compress::Index',
    writer => '_set_index',
);

has '_feat_count' => (
    is => 'ro',
    isa => 'HashRef[Int]',
    default => sub {{}},
    writer => '_set_feat_count',
);

has '_feat_class_count' => (
    is => 'ro',
    isa => 'HashRef[Int]',
    default => sub {{}},
    writer => '_set_feat_class_count',
);

sub see {
    my ($self, $x, $y) = @_;

    # TODO $x can possibly be also a hash
    foreach my $feat (@$x) {
        $self->_feat_class_count->{$feat . "_" . $y}++;
        $self->_feat_count->{$feat}++;
    }

    push @{$self->_unprocessed_instances}, { x => $x, y_str => $y };
}

sub _assign_idx {
    my ($self, $instances) = @_;
    
    if (!defined $self->_current_index) {
        $self->_set_index( Treex::Tool::Compress::Index->new() );
    }

    foreach my $inst (@$instances) {
        my $y_idx = $self->_current_index->get_index( $inst->{y_str} );
        $inst->{y} = $y_idx;
    }
}

sub learn {
    my ($self, $print_line) = @_;
    
    $self->_log_info_verbose("Vowpal Wabbit (VW) online learning:");

    my @shuffled_ex = shuffle @{$self->_unprocessed_instances};

    $self->_assign_idx( \@shuffled_ex );

    my @vw_examples = map { Treex::Tool::ML::VowpalWabbit::Util::instance_to_vw_str( $_->{x}, $_->{y}, $_->{y_str} ) }
        @shuffled_ex;

    #if ($print_line) {
    #    my @all_classes = (1 .. $self->_current_index->last_idx);
    #    my @multiline = map { Treex::Tool::ML::VowpalWabbit::Util::instance_to_multiline( $_->{x}, $_->{y}, \@all_classes, 0 ) }
    #        @{$self->_unprocessed_instances};
    #    #print join "\n", @vw_examples;
    #    print join "\n", @multiline;
    #}
    
    my $num_classes = $self->_current_index->last_idx;

    my $quiet = $self->verbose < 2 ? "--quiet" : "";
    my $init_str = "-d /dev/null $quiet --sequence_max_length 1024 --noconstant --oaa $num_classes";
    
    my $vw = VowpalWabbit::initialize($init_str);

    $self->_log_info_verbose("VW: classes = " . $num_classes);
    $self->_log_info_verbose("VW: passes = " . $self->passes);
    
    foreach my $pass (1 .. $self->passes) {
        $self->_log_info_verbose("VW: pass no. $pass");
        foreach my $example_line (@vw_examples) {
            my $example = VowpalWabbit::read_example($vw, $example_line);
            $vw->learn($vw, $example);
            VowpalWabbit::finish_example($vw, $example);
        }
    }
    my $buff = VowpalWabbit::get_buffered_regressor($vw);
    #print STDERR "Total size: " . total_size($buff) . "\n";
    VowpalWabbit::finish($vw);

    
    # A SLIGHTLY WEIRD WAY HOW TO GET THE LEARNT PARAMETERS FROM VW
    # 1. load the trained model again, this time just for testing and the --audit parameter on
    # 2. create an instance that consists of all the features seen in the training data
    # 3. predict a class for the instance
    # 4. retrieve the parameters assigned to each of the features

    $vw = VowpalWabbit::create_vw();
    VowpalWabbit::add_buffered_regressor($vw, $buff);
    VowpalWabbit::initialize_empty_vw($vw, "-t /dev/null --audit --quiet");

    my $all_example_str = Treex::Tool::ML::VowpalWabbit::Util::instance_to_vw_str( [keys %{$self->_feat_count}] );
    my $all_example = VowpalWabbit::read_example($vw, $all_example_str);

    # suppress the audit info being printed on STDOUT by VW
    open my $saveout, ">&STDOUT";
    open STDOUT, '>', "/dev/null";
    $vw->learn($vw, $all_example);
    open STDOUT, ">&", $saveout;

    my $feats = VowpalWabbit::get_feats($all_example);
    my $weights = $vw->get_weights($vw, $all_example);
    VowpalWabbit::finish_example($vw, $all_example);
    VowpalWabbit::finish($vw);

    # remove namespace from feat names
    my @feats_no_ns = map {$_ =~ s/^[^^]*\^(.*)$/$1/; $_} @$feats;
    my $model_hash = $self->_convert_to_hash(\@feats_no_ns, $weights);

    print STDERR Dumper($model_hash);

    my $model = Treex::Tool::ML::Classifier::Linear->new({
        model => $model_hash,
    });
    
    #my $model = Treex::Tool::ML::VowpalWabbit::Model->new({
    #    model => $buff,
    #    index => $self->_current_index,
    #});
    
    return $model;
}

sub forget_all {
    my ($self) = @_;
    $self->_set_index( Treex::Tool::Compress::Index->new() );
    $self->_set_instances( [] );
    $self->_set_feat_count( {} );
    $self->_set_feat_class_count( {} );
}

sub cut_features {
    my ($self, $min_count) = @_;

    my @f_unproc = ();
    foreach my $ex (@{$self->_unprocessed_instances}) {
        my @f_feats = grep {$self->_feat_class_count->{$_ . "_" . $ex->{y_str}} >= $min_count} 
            @{$ex->{x}};
        if (scalar @f_feats > 0) {
            push @f_unproc, { x => \@f_feats, y_str => $ex->{y_str} };
           # log_info "AFTER: " . scalar @{$ex->{x}};
        }
    }
    $self->_set_instances( \@f_unproc );
}

sub _log_info_verbose {
    my ($self, $message) = @_;
    if ($self->verbose > 0) {
        log_info($message);
    }
}

sub _convert_to_hash {
    my ($self, $feats, $weights) = @_;

    my $k = $self->_current_index->last_idx;
    my $feat_num = scalar @$feats;

    $self->_current_index->build_inverted_index();

    my $model_hash = {};

    for (my $class_idx = 1; $class_idx <= $k; $class_idx++) {
        for (my $j = 0; $j < $feat_num; $j++) {
            my $weights_idx = $j + ($class_idx - 1)*$feat_num;
            # do not store 0 weights
            if ($weights->[$weights_idx]) {
                my $class_name = $self->_current_index->get_str_for_idx($class_idx);
                $model_hash->{$class_name}{$feats->[$j]} = $weights->[$weights_idx];
            }
        }
    }
    return $model_hash;
}

1;
