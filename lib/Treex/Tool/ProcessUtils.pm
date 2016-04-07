package Treex::Tool::ProcessUtils;

use strict;
use warnings;
use IPC::Open2;
use IPC::Open3;
use IO::Handle;

use Treex::Core::Log;

# Open a bipipe and set binmode to utf8.
sub bipipe {
    my $cmd     = shift;
    my $binmode = shift;
    if ( !defined $binmode ) {
        $binmode = ":utf8";
    }

    my @cmd_args = ( $cmd );
    if (ref($cmd) eq 'ARRAY') {
        @cmd_args = ( @$cmd, '' );
    }

    my $reader;
    my $writer;
    my $pid = open2( $reader, $writer, @cmd_args );
    log_fatal("Failed to open bipipe to: ". join " ", @cmd_args) if !$pid;
    $writer->autoflush(1);
    $reader->autoflush(1);

    binmode( $reader, $binmode );
    binmode( $writer, $binmode );

    return ( $reader, $writer, $pid );
}

# Open a bipipe and set binmode. Command line arguments are passed in @_
# This is useful on Windows because the returned $pid would be "windows cmd (shell) pid" otherwise,
# not pid of the executed program, which we need to kill at the end (on Windows).
sub bipipe_noshell {

    my $binmode = shift;
    #$binmode param is mandatory in this case
    #$binmode = ":utf8" if !defined $binmode;

    my $cmd = "@_";

    my $reader;
    my $writer;
    my $pid = open2( $reader, $writer, @_ );
    log_fatal "Failed to open bipipe to: $cmd" if !$pid;
    $writer->autoflush(1);
    $reader->autoflush(1);

    binmode( $reader, $binmode );
    binmode( $writer, $binmode );

    return ( $reader, $writer, $pid );
}

# Bipipe that reads both the child's STDOUT and the child's STDERR
# (fix for Windows as with bipipe_noshell).
sub verbose_bipipe_noshell {

    my ($binmode, @cmd) = @_;

    my $reader;
    my $writer;

    # open3: if err stream is false, connects it to output.
    my $pid = open3( $writer, $reader, 0 , @cmd );
    log_fatal "Failed to open verbose_bipipe to: @cmd" if !$pid;

    $writer->autoflush(1);
    $reader->autoflush(1);
    binmode( $reader, $binmode );
    binmode( $writer, $binmode );

    return ( $reader, $writer, $pid );
}


# Open a tripipe and set binmode to utf8.
sub verbose_bipipe {
    my $cmd     = shift;
    my $binmode = shift;
    if ( !defined $binmode ) {
        $binmode = ":utf8";
    }

    my $reader;
    my $writer;
    *ERR = *STDOUT;
    my $pid = open3( $reader, '>&ERR', '>&ERR', $cmd );
    log_fatal("Failed to open verbose_bipipe to: $cmd") if !$pid;

    #$writer->autoflush(1);
    #$reader->autoflush(1);

    binmode( $reader, $binmode );

    #binmode( $writer, $binmode );

    return ( $reader, $writer, $pid );
}

sub logging_bipipe {
    my $cmd     = shift;
    my $binmode = shift;
    if ( !defined $binmode ) {
        $binmode = ":utf8";
    }

    my $reader;
    my $writer;
    {

        # TODO use lexical filehandles instad
        no warnings 'once';
        open( LOG, '>>process_utils.log' );
    }
    my $pid = open3( $reader, $writer, '>&LOG', $cmd );
    log_fatal("Failed to open logging_pipe to: $cmd") if !$pid;
    $writer->autoflush(1);
    $reader->autoflush(1);

    binmode( $reader, $binmode );

    #binmode( $writer, $binmode );

    return ( $reader, $writer, $pid );
}

# Run a command very safely.
# Synopsis: safesystem(qw(echo hello)) or die;
sub safesystem {

    #print STDERR "Executing: @_\n";
    system(@_);
    if ( $? == -1 ) {
        print STDERR "Failed to execute: @_\n  $!\n";
        exit(1);
    }
    elsif ( $? & 127 ) {
        printf STDERR "Execution of: @_\n  died with signal %d, %s coredump\n",
            ( $? & 127 ), ( $? & 128 ) ? 'with' : 'without';
        exit(1);
    }
    else {
        my $exitcode = $? >> 8;

        # print STDERR "Exit code: $exitcode\n" if $exitcode;
        return !$exitcode;
    }
}

my %unit_to_multiplier = qw(
    B 1
    kB 1024
    MB 1048576
    GB 1073741824
);

sub get_bytes {
    my $fn  = shift;
    my $key = shift;
    my $bytes;
    open my $INF, $fn or die "Can't read $fn";
    while (<$INF>) {
        chomp;
        if (/^$key\s*([0-9]+)\s*([a-zA-Z]+)\s*$/) {
            my $amount = $1;
            my $unit   = $2;
            die "Bad unit in $_" if !defined $unit_to_multiplier{$unit};
            $bytes = $amount * $unit_to_multiplier{$unit};
            last;
        }
    }
    close $INF;
    return $bytes;
}

# Returns the percentage of physical memory I am occupying.
sub memusage {
    my $memtotal = get_bytes( "/proc/meminfo",     "MemTotal:" );
    my $memusage = get_bytes( "/proc/self/status", "VmPeak:" );
    return $memusage / $memtotal * 100;
}

# Returns the absolute size of occupied memory.
sub memusage_absolute {
    return get_bytes( '/proc/self/status', 'VmPeak:' );
}

# Calls waitpid(ARG1, 0) and *preserves the exit status!!* of the whole perl process
sub safewaitpid {
    my $pid = shift;

    # we need to preserve $?, the exit status of the whole process
    my $saved_exit_status = $?;
    waitpid( $pid, 0 );
    $? = $saved_exit_status;    # restore the original exit status
}

1;

# Copyright 2008 Ondrej Bojar
