package Treex::Tool::Python::RunFunc;

use Moose;
use Treex::Core::Common;
use Treex::Tool::ProcessUtils;
use IO::Handle;


# Python slave application controls (bipipe handles, application PID)
has '_read_handle'  => ( is => 'rw', isa => 'FileHandle' );
has '_write_handle' => ( is => 'rw', isa => 'FileHandle' );
has '_python_pid'     => ( is => 'rw', isa => 'Int' );


# Launch the slave Python process
sub BUILD {

    my ( $self, $params ) = @_;
      
    my $file = __FILE__;
    $file =~ s/\/[^\/]*$//;
    $file .= '/execute.py';
            
    log_info('Running Python slave process');
    my ( $read, $write, $pid ) = Treex::Tool::ProcessUtils::bipipe('python ' . $file);

    $read->autoflush();
    $write->autoflush();    
    $self->_set_read_handle($read);
    $self->_set_write_handle($write);
    $self->_set_python_pid($pid);

    my $res = $self->command("print 'Hello'");
    log_info('Python slave process started: ' . $res);
    return;
}


# Run Python commands and capture their output
sub command {
    
    my ( $self, $cmd ) = @_;
    my $output = '';

    print { $self->_write_handle } $cmd . "\nprint '<<<<END>>>>'\n";
    $self->_write_handle->flush();
    
    my $fh = $self->_read_handle;
    my $ended = 0;
    while (my $line = <$fh>) {
        $line =~ s/\r?\n$/\n/;
        if ($line eq "<<<<END>>>>\n"){
            $ended = 1;
            last;
        }
        $output .= $line;
    }
    
    if (!$ended){
        log_fatal('Python slave process closed output prematurely (see above for error messages).');
    }

    $output =~ s/\n$// if ($output =~ /^[^\n]*\n$/);
    return $output;
}


1;

__END__


=encoding utf-8

=head1 NAME

Treex::Tool::Python::RunFunc - execute Python commands from inside Treex

=head1 SYNOPSIS

 use Treex::Tool::Python::RunFunc;

 my $python = Treex::Tool::Python::RunFunc->new();
 
 my $var = $python->command("x = 1\nprint x + 1\n");
 print $var, "\n"; # print '2' 

=head1 DESCRIPTION

This allows one to run any Python commands/functions in a slave process
and pass their output (as strings) back to Treex.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
