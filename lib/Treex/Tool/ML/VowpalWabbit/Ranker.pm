package Treex::Tool::ML::VowpalWabbit::Ranker;

use Moose;
use Treex::Tool::ProcessUtils;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);
use Treex::Tool::ML::VowpalWabbit::Util;

with 'Treex::Tool::ML::Ranker';

has 'vw_path' => (is => 'ro', isa => 'Str', required => 1, default => $ENV{TMT_ROOT}.'/share/installed_tools/ml/vowpal_wabbit-v8.1-3cf3f692/vowpalwabbit/vw');
has '_read_handle'  => ( is => 'rw', isa => 'FileHandle' );
has '_write_handle' => ( is => 'rw', isa => 'FileHandle' );

has 'model_path' => (is => 'ro', isa => 'Str', required => 1);

sub BUILD {
    my ($self) = @_;
    
    my $model_path = $self->_locate_model_file($self->model_path, $self);
    my $command = sprintf "%s -t -i %s -p /dev/stdout --loss_function=logistic --probabilities 2> /dev/null", $self->vw_path, $model_path;

    my ( $read, $write, $pid ) = Treex::Tool::ProcessUtils::bipipe($command);
    
    $read->autoflush();
    $write->autoflush();    
    $self->_set_read_handle($read);
    $self->_set_write_handle($write);
}

sub _locate_model_file {
    my ($self, $path) = @_;
    
    if (!-f $path) {
        $path = require_file_from_share($path, ref($self));
    }
    log_fatal 'File ' . $path . ' does not exist.' 
        if !-f $path;
    return $path;
}

sub rank {
    my ($self, $instance) = @_;

    my ($cands, $shared) = @$instance;
    my $cands_count = scalar @$cands;

    my $instance_str = Treex::Tool::ML::VowpalWabbit::Util::format_multiline($instance);
    print {$self->_write_handle} $instance_str . "\n";
    #if ($debug) {
    #    print STDERR $instance_str . "\n";
    #}

    my @probs = ();

    my $fh = $self->_read_handle;
    #my $empty_line = <$fh>;
    #if ($empty_line !~ /^\s*$/) {
    #    log_fatal "First line of VW output must be empty (unless -r instead of -p)";
    #}
    my $line;
    for (my $i = 0; $i < $cands_count; $i++) { 
        $line = <$fh>;
        chomp $line;
        my ($prob, $tag) = split / /, $line;
        push @probs, $prob;
    }
    $line = <$fh>;
    log_fatal 'Vowpal Wabbit outputs more results than desired.' if ($line !~ /^\s*$/);
    return @probs;
}

1;
