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
    
    log_info("Vowpal Wabbit (VW) online learning:");
    
    my $num_classes = $self->_current_index->last_idx;
    my $vw = VowpalWabbit::initialize("--sequence_max_length 1024 --noconstant --oaa $num_classes");

    log_info("VW: classes = " . $num_classes);
    log_info("VW: passes = " . $self->passes);
    
    foreach my $pass (1 .. $self->passes) {
        log_info("VW: pass no. $pass");
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

1;
