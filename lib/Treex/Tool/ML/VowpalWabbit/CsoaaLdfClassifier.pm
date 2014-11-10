package Treex::Tool::ML::VowpalWabbit::Classifier;

use Moose;
use ProcessUtils;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);


has 'vw_path' => ( is => 'ro', isa => 'Str', required => 1, default => '/home/odusek/work/tools/vowpal_wabbit/vowpalwabbit/vw' );

has '_read_handle'  => ( is => 'rw', isa => 'FileHandle' );
has '_write_handle' => ( is => 'rw', isa => 'FileHandle' );

has 'model_path' => ( is => 'ro', isa => 'Str', required => 1 );

sub BUILD {
    my ($self) = @_;

    my $model_path = $self->_locate_model_file( $self->model_path, $self );
    my $command = sprintf "%s -t -i %s -p /dev/stdout 2> /dev/null", $self->vw_path, $model_path;

    my ( $read, $write, $pid ) = ProcessUtils::bipipe($command);

    $read->autoflush();
    $write->autoflush();
    $self->_set_read_handle($read);
    $self->_set_write_handle($write);
}

sub _locate_model_file {
    my ( $self, $path ) = @_;

    if ( !-f $path ) {
        $path = require_file_from_share( $path, ref($self) );
    }
    log_fatal 'File ' . $path . ' does not exist.' if !-f $path;
    return $path;
}

sub classify {
    my ( $self, $instance_str ) = @_;

    print { $self->_write_handle } $instance_str;

    my $fh = $self->_read_handle;
    my $class = undef;

    while ( my $line = <$fh> ) {
        chomp $line;
        last if ( $line =~ /^\s*$/ );
        my ( $select, $label ) = split / /, $line, 2;
        if ( $select > 0 ){
            $class = $label;
        }
    }
    return $class;
}

1;
