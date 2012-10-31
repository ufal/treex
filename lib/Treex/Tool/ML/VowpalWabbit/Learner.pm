package Treex::Tool::ML::VowpalWabbit::Learner;

use Moose;

use Treex::Core::Common;

use VowpalWabbit;
use Treex::Tool::Compress::Index;

use IO::Zlib;
use File::Slurp;

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
    isa => 'ArrayRef[Str]',
    default => sub {[]},
    writer => '_set_instances',
);

has '_current_index' => (
    is => 'ro',
    isa => 'Treex::Tool::Compress::Index',
    writer => '_set_index',
);

sub see {
    my ($self, $x, $y) = @_;

    if (!defined $self->_current_index) {
        $self->_set_index( Treex::Tool::Compress::Index->new() );
    }
    my $y_idx = $self->_current_index->get_index( $y );
    my $instance_str = Treex::Tool::ML::VowpalWabbit::Util::instance_to_vw_str( $x, $y_idx );

    push @{$self->_unprocessed_instances}, $instance_str;
}

sub learn {
    my ($self) = @_;
    
    
    $self->_log_info_verbose("Vowpal Wabbit (VW) online learning:");
    
    my $num_classes = $self->_current_index->last_idx;
    my $quiet = $self->verbose < 2 ? "--quiet" : "";
    my $init_str = "$quiet --sequence_max_length 1024 --noconstant --oaa $num_classes";
    
    my $vw = VowpalWabbit::initialize($init_str);

    $self->_log_info_verbose("VW: classes = " . $num_classes);
    $self->_log_info_verbose("VW: passes = " . $self->passes);
    
    foreach my $pass (1 .. $self->passes) {
        $self->_log_info_verbose("VW: pass no. $pass");
        foreach my $example_line (@{$self->_unprocessed_instances}) {
            my $example = VowpalWabbit::read_example($vw, $example_line);
            $vw->learn($vw, $example);
            VowpalWabbit::finish_example($vw, $example);
        }
    }
    my $buff = VowpalWabbit::get_buffered_regressor($vw);
    #print STDERR "Total size: " . total_size($buff) . "\n";
    VowpalWabbit::finish($vw);

    my $model = Treex::Tool::ML::VowpalWabbit::Model->new({
        model => $buff,
        index => $self->_current_index,
    });
    
    return $model;
}

sub forget_all {
    my ($self) = @_;
    $self->_set_index( Treex::Tool::Compress::Index->new() );
    $self->_set_instances( [] );
}

sub _log_info_verbose {
    my ($self, $message) = @_;
    if ($self->verbose > 0) {
        log_info($message);
    }
}

1;
