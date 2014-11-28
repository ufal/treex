package Treex::Block::Read::ProducerReader;

use Moose;
use Treex::Core::Common;
use Treex::Core::Log;
with 'Treex::Core::DocumentReader';

use POE;
use IO::Socket;
use POE qw(Wheel::SocketFactory Wheel::ReadWrite);
use POE qw(Component::Server::TCP Filter::Reference);
use Data::Dumper;
use Time::HiRes;
use Readonly;
use Carp;

has reader => (
    isa      => 'Treex::Core::DocumentReader',
    is       => 'ro',
    required => 1
);

has port => (
    isa      => 'Int',
    is       => 'ro',
    required => 1
);

has host => (
    isa => 'Str',
    is  => 'ro',
);

has _handle => (
    isa => 'FileHandle',
    is  => 'rw'
);

has status => (
    isa => 'HashRef',
    is  => 'rw'
);

has '_files' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} }
);

has '_jobs' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { {} }
);

has 'workdir' => (
    isa => 'Str',
    is  => 'ro',
);

has writers => (
    is      => 'rw',
    does    => 'ArrayRef[Treex::Block::Write::BaseWriter]',
    default => sub { [] }
);

has _file_count => (
    isa     => 'Int',
    is      => 'rw',
    default => 0,
);

has _total_file_count => (
    isa     => 'Int',
    is      => 'rw',
    default => 0,
);

has _finished_count => (
    isa     => 'Int',
    is      => 'rw',
    default => 0
);

has _max_submitted => (
    isa     => 'Int',
    is      => 'rw',
    default => 2
);

has _submitted_limit => (
    isa     => 'Int',
    is      => 'rw',
    default => 5
);

has _crashed_jobs => (
    isa     => 'Int',
    is      => 'rw',
    default => 0
);

has _finished_jobs => (
    isa     => 'Int',
    is      => 'rw',
    default => 0
);

has log_file => (
    isa => 'Str',
    is  => 'ro',
);

has 'survive' => (
    is      => 'rw',
    isa     => 'Bool',
    default => 0,
);

sub BUILD {
    my $self = shift;
    $self->_set_submitted_limit( int( $self->jobs / 2 ) );

    my $result    = 1;
    my $reconnect = 0;

    open( my $fh_log, ">:encoding(UTF-8)", $self->log_file ) or croak $! . " - " . $self->log_file;

    do {
        POE::Session->create(
            inline_states => {
                _start => sub {

                    # Start the server.
                    $reconnect = 0;
                    $_[HEAP]{server} = POE::Wheel::SocketFactory->new(
                        BindPort     => $Treex::Core::Parallel::Head::PORT,
                        SuccessEvent => "on_client_accept",
                        FailureEvent => "on_server_error",
                        Filter       => POE::Filter::Reference->new(),
                    );
                },
                on_client_accept => sub {

                    # Begin interacting with the client.
                    my $client_socket = $_[ARG0];
                    my $io_wheel      = POE::Wheel::ReadWrite->new(
                        Handle     => $client_socket,
                        InputEvent => "on_client_input",
                        ErrorEvent => "on_client_error",
                        Filter     => POE::Filter::Reference->new(),
                    );
                    $_[HEAP]{client}{ $io_wheel->ID() } = $io_wheel;
                },
                on_server_error => sub {

                    # Shut down server.
                    my ( $operation, $errnum, $errstr ) =
                        @_[ ARG0, ARG1, ARG2 ];
                    log_warn "MSG: Server $operation error $errnum: $errstr\n";

                    # address already used
                    if ( $errnum == 98 ) {
                        $reconnect              = 1;
                        $Treex::Core::Parallel::Head::PORT = int( 30000 + rand(32000) );
                    }
                    delete $_[HEAP]{server};
                },
                on_client_input => sub {

                    # Handle client input.
                    my ( $kernel, $sender, $heap, $input, $wheel_id ) =
                        @_[ KERNEL, SESSION, HEAP, ARG0, ARG1 ];
                    my ( $jobid, $function ) = split( /\t/, $$input );

                    my $msg          = "Client $jobid: $function";
                    my $finished_str = "__finished__";
                    $result = $finished_str;

                    if (( $self->survive == 0 && $self->_crashed_jobs == 0 )
                        ||
                        ( $self->survive == 1 && $self->_crashed_jobs < $self->jobs )
                        )
                    {
                        if ( $function =~ /cmd_(.*)(\t(.*))?/ ) {
                            my $act_cmd = $1;
                            if ( $act_cmd eq "started" ) {
                                $result = "started";
                            }
                            elsif ( $act_cmd eq "fatalerror" ) {
                                $result = "fatalerror";

                                # zjisti, ktery to je
                                my $finished_file = $self->_jobs->{$jobid};

                                if ($finished_file) {

                                    # error during document processing

                                    $msg .= "; Crashed $finished_file";
                                    if ( $self->_files->{$finished_file}->{'finished'} ) {
                                        $msg .= "; Already finished!!!";
                                        $self->_process_created_files( $jobid, 0, 1 );
                                    }
                                    else {
                                        $self->_process_created_files( $jobid, 0, 1 );
                                        $self->_files->{$finished_file}->{'crashed'}++;
                                        $msg .= "; Crashed " . $self->_files->{$finished_file}->{'crashed'} . " times";
                                        if ( $self->_files->{$finished_file}->{'crashed'} > $self->_submitted_limit - 1 ) {
                                            $self->status->{ "doc_" . $finished_file . "_fatalerror" } = $jobid;
                                            $self->_set_finished_count( $self->_finished_count + 1 );
                                        }
                                    }
                                }
                                else {
                                    $msg .= "; Crashed during loading";
                                }
                                $self->status->{"info_fatal_job"} = $jobid;
                                $self->status->{"info_fatal_doc"} = $finished_file;

                                # increase number of crashed jobs
                                $self->status->{'info_fatalerror'} = $self->status->{'info_fatalerror'} + 1;
                                $self->_set_crashed_jobs( $self->_crashed_jobs + 1 );
                                my $remaining_jobs = $self->jobs - $self->_finished_jobs - $self->_crashed_jobs;

                                #TODO: hack
                                if ( $remaining_jobs < 0 ) {
                                    $remaining_jobs = 0;
                                }
                                log_info( "Remains " . $remaining_jobs . " jobs (" . $self->_crashed_jobs . " crashed) out of " . $self->jobs );

                                $self->status->{'info_crashed_jobs'} = $self->_crashed_jobs;
                                if ( $remaining_jobs == 0 ) {
                                    $self->_mark_as_finished();
                                }
                            }

                            # delete auxiliary created files
                            if ( $act_cmd eq "finished" ) {

                                my $orig_dir =
                                    $self->workdir . '/output__JOB__' . $jobid . '/';

                                #qx(rm -rf $orig_dir);

                                for my $writer ( @{ $self->writers } ) {
                                    my $path = $writer->path;
                                    if ($path) {
                                        $path =~ s/\/+$//;
                                        $path .= "__JOB__" . $jobid;

                                        #log_info("Client $jobid: DELETING $path");
                                        #qx(rm -rf $path);
                                    }
                                }

                                $self->_set_finished_jobs( $self->_finished_jobs + 1 );
                            }

                            $self->status->{ "job_" . $jobid . "_" . $act_cmd } = 1;
                        }
                        else {
                            if ( $self->reader->isa('Treex::Block::Read::BaseAlignedReader') && $function eq 'next_filename') {
                                $function = 'next_filenames';
                            }

                            my $received = $self->reader->$function();

                            # mark job as finished
                            my $finished_file = $self->_jobs->{$jobid};

                            if ($finished_file) {
                                $msg .= "; Finished $finished_file";
                                if ( $self->_files->{$finished_file}->{'finished'} ) {
                                    $msg .= "; Already finished!!!";
                                    $self->_process_created_files( $jobid, 1, 0 );
                                }
                                else {
                                    $self->_process_created_files( $jobid, 0, 0 );

                                    $self->_files->{$finished_file}->{'finished'} = time();

                                    $self->status->{ "doc_" . $finished_file . "_finished" } = $jobid;

                                    $self->_set_finished_count( $self->_finished_count + 1 );
                                }
                            }

                            if ($received) {
                                $result = { 'result' => $received };
                                $self->_set_doc_number( $self->doc_number + 1 );

                                if ( $self->reader->isa('Treex::Block::Read::BaseReader') ) {
                                    $result->{file_number} = $self->reader->file_number;
                                }
                                elsif ( $self->reader->isa('Treex::Block::Read::BaseAlignedReader') ) {
                                    $result->{doc_number}  = $self->doc_number;
                                    $result->{file_number} = $self->reader->_file_number;
                                }

                                # mark job as started
                                $self->status->{ "doc_" . $self->doc_number . "_started" } = $jobid;

                                $self->_files->{ $result->{file_number} } = {
                                    'started'   => time(),
                                    'job'       => $jobid,
                                    'result'    => $result,
                                    'submitted' => 1
                                };

                                $msg .= "; Assigned: " . $result->{file_number};

                                $self->_set_file_count( $result->{file_number} );
                            }
                            else {
                                $self->_set_total_file_count( $self->_file_count );

                                if ( $Treex::Core::Parallel::Head::SPECULATIVE_EXECUTION ) {

                                    my $not_finished = 0;
                                    SUBMITS:
                                    for ( my $submitted = $self->_max_submitted; $submitted < $self->_submitted_limit; $submitted++ ) {

                                        #$not_finished = 0;
                                        for ( my $i = $self->_file_count; $i > 1; $i-- ) {
                                            if ( !$self->_files->{$i}->{finished} ) {

                                                #        $not_finished++;
                                                if ( $self->_files->{$i}->{submitted} < $submitted ) {
                                                    $self->_files->{$i}->{submitted} += 1;
                                                    $result = $self->_files->{$i}->{result};
                                                    $msg .= "; Assigned: " . $result->{file_number} . "; AGAIN: " . $self->_files->{$i}->{submitted};
                                                    last SUBMITS;
                                                }
                                            }
                                            $self->_set_max_submitted($submitted);
                                        }
                                    }
                                }

                                if ( $self->_finished_count == $self->_file_count )
                                {
                                    $self->_mark_as_finished();
                                    delete $_[HEAP]{server};
                                    $_[KERNEL]->stop();
                                }
                            }

                            # remember wich job is working on which file
                            if ( ref($result) ) {
                                $self->_jobs->{$jobid} = $result->{file_number};
                            }
                        }
                    }
                    $_[HEAP]{client}{$wheel_id}->put( \$result );

                    #log_info($msg);
                    print $fh_log running_time() . "\t" . $msg . "\n";
                },
                on_client_error => sub {

                    # Handle client error, including disconnect.
                    my $wheel_id = $_[ARG3];
                    delete $_[HEAP]{client}{$wheel_id};
                },
                }
        );
        POE::Kernel->run();
    } while ( $reconnect == 1 );

    return;
}

sub _mark_as_finished {
    my $self = shift;

    # mark all remaining files as skipped
    my $max_file = $self->_total_file_count;
    if ( !$max_file ) {
        $max_file = $self->_file_count * 100;
    }

    if ( $max_file > 20000 ) {
        $max_file = 20000;
    }

    for my $id ( 1 .. $max_file ) {
        if (!defined( $self->status->{ "doc_" . $id . "_finished" } )
            && !defined( $self->status->{ "doc_" . $id . "_fatalerror" } )
            )
        {
            $self->status->{ "doc_" . $id . "_skipped" } = 1;
        }
    }

    for my $i ( 1 .. $self->jobs ) {
        $self->status->{ "job_" . $i . "_started" }  = 1;
        $self->status->{ "job_" . $i . "_loaded" }   = 1;
        $self->status->{ "job_" . $i . "_finished" } = 1;
    }

    $self->status->{"___FINISHED___"} = 1;
    return;
}

sub next_document {
    log_fatal("AAAAAAAAA");
}

sub number_of_documents {
    log_fatal("AAAAAAAAA");
}

sub DESTROY {
    my $self = shift;
    return;
}

sub _process_created_files {
    my ( $self, $jobid, $delete, $error ) = @_;

    my $finished_file = $self->_jobs->{$jobid};

    my $output_dir = "output";
    if ($error) {
        $output_dir = "error";
    }

    my $global_orig_dir = Treex::Core::Parallel::Head::construct_output_dir_name(
        $self->workdir . '/output', $jobid, $self->host, $self->port
    );
    my $global_target_dir = $self->workdir . "/$output_dir/";

    my @cmds = ();

    if ($Treex::Core::Parallel::Head::SPECULATIVE_EXECUTION) {
        for my $writer ( @{ $self->writers } ) {
            my $path = $writer->path;

            #log_warn("$writer - PATH: " . $writer->path . "; TO: " . $writer->to);
            if ( !$path ) {
                $path = "./";
            }

            my $target_path = $path;
            $target_path .= "/";

            if ( $path ne "./" ) {
                $path =~ s/\/+$//;
            }

            $path = Treex::Core::Parallel::Head::construct_output_dir_name( $path, $jobid, $self->host, $self->port );

            #log_warn("BEFORE: " . join(", ", glob $path . "/*"));

            if ( $writer->to && $writer->to eq "-" ) {

                my $out_file = $global_target_dir . '/'
                    . sprintf( "doc%07d.stdout", $finished_file );
                my $in_file = $path . "/*";
                my $try     = 0;

                if ($delete) {
                    push( @cmds, "rm $in_file 2>/dev/null" );
                }
                else {
                    push( @cmds, "mv $in_file $out_file  2>/dev/null" );
                }

            }
            else {

                #log_info("Client $jobid: mv $path/* $target_path/");
                if ($delete) {
                    qx(rm $path/* 2>/dev/null);
                }
                else {
                    qx(mv $path/* $target_path/ 2>/dev/null);
                }
            }
        }
    }

    # move all related files to output folder
    #log_warn("GLOBAL BEFORE: " . join(", ", glob $global_orig_dir . "/*"));
    #log_warn("mv $global_orig_dir/* $global_target_dir");
    if ($delete) {
        qx(rm -f $global_orig_dir/* 2>/dev/null);
    }
    else {
        qx(mv $global_orig_dir/* $global_target_dir 2>/dev/null);
    }

    #log_warn("GLOBAL AFTER: " . join(", ", glob $global_orig_dir . "/*"));
    for my $cmd (@cmds) {

        #log_info("Client $jobid: " . $cmd);
        qx($cmd 2>/dev/null);
    }

    # log_warn("TARGET DIR: " . join(", ", glob $global_target_dir . "/*"));
    
    return;
}

1;

__END__
=head1 NAME

Treex::Block::Read::ProducerReader

=head1 AUTHOR

Martin Majliš

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
