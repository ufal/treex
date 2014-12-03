package Treex::Tool::LXSuite::Client;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;
use Treex::Tool::ProcessUtils;
use File::Basename;


has debug => ( isa => 'Bool', is => 'ro', required => 0, default => 0 );
#has lxsuite_host => ( isa => 'Str', is => 'ro', required => 0, default => "194.117.45.198" );
#has lxsuite_host => ( isa => 'Str', is => 'ro', required => 0, default => "194.117.45.194" );
has lxsuite_host => ( isa => 'Str', is => 'ro', required => 0, default => "localhost" );
has lxsuite_port => ( isa => 'Int', is => 'ro', required => 0, default => 10000 );
has lxsuite_key => ( isa => 'Str', is => 'ro', required => 1 );
has lxsuite_mode => ( isa => 'Str', is => 'ro', required => 1 );
has [qw( _reader _writer _pid )] => ( is => 'rw' );


sub BUILD {
    my $self = shift;
    my $client_dir = dirname(__FILE__);
    my $host = $self->lxsuite_host;
    my $port = $self->lxsuite_port;
    my $key  = $self->lxsuite_key;
    my $mode = $self->lxsuite_mode;
    my $cmd = "$client_dir/lxsuite_client.py $host $port $key $mode - -";
    my ( $reader, $writer, $pid ) =
        Treex::Tool::ProcessUtils::bipipe($cmd, ':encoding(utf-8)');
    $self->_set_reader( $reader );
    $self->_set_writer( $writer );
    $self->_set_pid( $pid );
}

sub DEMOLISH {
    my $self = shift;
    close( $self->_writer ) if defined $self->_writer;
    close( $self->_reader ) if defined $self->_reader;
    Treex::Tool::ProcessUtils::safewaitpid( $self->_pid ) if defined $self->_pid;
}

1;

__END__


=head1 NAME

Treex::Tools::LXSuite

=head1 SYNOPSIS

Extend this class and use $self->_reader and $self->_writer to 
 communicate with lxsuite_client process.

=head1 AUTHORS

Luís Gomes <luis.gomes@di.fc.ul.pt>, <luismsgomes@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by NLX Group, Universidade de Lisboa
