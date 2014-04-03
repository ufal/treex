package Treex::Tool::ML::VowpalWabbit::Ranker;

use Moose;
use Treex::Core::Common;
use ProcessUtils;

has 'vw_path' => (is => 'ro', isa => 'Str', required => 1, default => '/net/cluster/TMP/mnovak/tools/vowpal_wabbit/vowpalwabbit/vw');
has '_read_handle'  => ( is => 'rw', isa => 'FileHandle' );
has '_write_handle' => ( is => 'rw', isa => 'FileHandle' );

has 'model_path' => (is => 'ro', isa => 'Str', required => 1);

sub BUILD {
    my ($self) = @_;

    my $command = sprintf "%s -t -i %s --ring_size 1024 -p /dev/stdout 2> /dev/null", $self->vw_path, $self->model_path;

    my ( $read, $write, $pid ) = ProcessUtils::bipipe($command);
    
    $read->autoflush();
    $write->autoflush();    
    $self->_set_read_handle($read);
    $self->_set_write_handle($write);
}

sub predict {
    my ($instance) = @_;

    my $instance_str = Treex::Tool::ML::VowpalWabbit::Util::instance_to_multiline($instance, undef, undef, 1, undef);
    print {$self->_write_handle} $instance_str . "\n";

    my $fh = $self->_read_handle;
    while (my $line = <$fh>) {
    }

}
