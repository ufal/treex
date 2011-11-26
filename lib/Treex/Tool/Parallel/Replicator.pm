package Treex::Tool::Parallel::Replicator;

use Moose;
use Treex::Core::Common;
use File::Temp qw(tempdir);
use Cwd 'abs_path';
use Treex::Tool::Parallel::MessageBoard;

has path => (
    is => 'rw',
    isa => 'Str',
    default => '.',
    documentation => 'directory in which working directory structure will be created',
);

has workdir => (
    is => 'rw',
    isa => 'Str',
    documentation => 'working directory created for storing messages',
);

has jobs => (
    is => 'rw',
    isa => 'Int',
    default => sub {10},
    documentation => 'total number of replicant jobs (not counting the hub)',
);

has rid => (
    is => 'rw',
    isa => 'Int',
    documentation => 'Replicant ID, number between zero (for hub) and the number of jobs',
);

has message_board => (
    is => 'rw',
    documentation => 'message board shared by the hub and all replicants',
);

has 'sge_job_numbers' => (
    is            => 'rw',
    documentation => 'list of numbers of jobs executed on sge',
    default       => sub { [] },
);

sub BUILD {
    my ( $self ) = @_;

    if ( $ENV{REPLICATOR_WORKDIR} ) {
        $self->_initialize_replicant();
    }

    else {
        $self->_initialize_hub();
    }
}


sub _initialize_hub {
    my ( $self ) = @_;

    $self->set_rid(0);

    # STEP 1 - create working directory for the replicator
    if ( not $self->workdir ) {
        my $counter;
        my $directory_prefix;
        my @existing_dirs;

        # search for the first unoccupied directory prefix
        do {
            $counter++;
            $directory_prefix = sprintf $self->path."/%03d_replicator_", $counter;
            @existing_dirs = glob "$directory_prefix*";
        }
            while (@existing_dirs);

        my $directory = tempdir "${directory_prefix}XXXXX" or log_fatal($!);
        $self->set_workdir($directory);
        log_info "Working directory $directory created";
    }

    # STEP 2 - create message board
    $self->set_message_board(
        Treex::Tool::Parallel::MessageBoard->new(
            current => 1,
            path => $self->workdir,
            sharers => $self->jobs + 1,
        )
      );

    # STEP 3 - create bash script for jobs
    $self->_create_job_scripts();

    # STEP 4 - send the jobs to the cluster
    $self->_run_job_scripts;


}

sub _create_job_scripts { # mostly copied from Treex::Core::Run
    my ($self)      = @_;
    my $current_dir = Cwd::cwd;
    my $workdir     = $self->workdir;
    mkdir $self->workdir."/scripts" or log_fatal $!;
    foreach my $number ( 1 .. $self->jobs ) {
        my $jobnumber = sprintf( "%03d", $number );
        my $script_filename = "scripts/job$jobnumber.sh";
        open my $J, ">", "$workdir/$script_filename" or log_fatal $!;
        print $J "#!/bin/bash\n\n";
        print $J "echo \$HOSTNAME > $current_dir/$workdir/output/job$jobnumber.started\n";
        print $J "export PATH=/opt/bin/:\$PATH > /dev/null 2>&1\n\n";
        print $J "cd $current_dir\n\n";
        print $J "source " . Treex::Core::Config->lib_core_dir()
            . "/../../../../config/init_devel_environ.sh 2> /dev/null\n\n";    # temporary hack !!!

        print $J "export REPLICATOR_WORKDIR=$workdir\n";
        print $J "export REPLICATOR_NUMBER=$number\n";

        print $J "$0 " . (join ' ', @ARGV)
            . " 2>> $workdir/output/job$jobnumber.started\n\n";
        print $J "touch $workdir/output/job$jobnumber.finished\n";
        close $J;
        chmod 0777, "$workdir/$script_filename";
    }
    return;
}

sub _run_job_scripts {
    my ($self) = @_;
    my $workdir = $self->workdir;
    if ( substr( $workdir, 0, 1 ) ne '/' ) {
        $workdir = "./$workdir";
    }
    foreach my $jobnumber ( 1 .. $self->jobs ) {
        my $script_filename = "scripts/job" . sprintf( "%03d", $jobnumber ) . ".sh";

        if ( $self->local ) {
            system "$workdir/$script_filename &";
        }
        else {
            open my $QSUB, "cd $workdir && qsub -cwd " . $self->qsub . " -e output/ -S /bin/bash $script_filename |" or log_fatal $!;    ## no critic (
ProhibitTwoArgOpen)

            my $firstline = <$QSUB>;
            close $QSUB;
            chomp $firstline;
            if ( $firstline =~ /job (\d+)/ ) {
                push @{ $self->sge_job_numbers }, $1;
            }
            else {
                log_fatal 'Job number not detected after the attempt at submitting the job. ' .
                    "Perhaps it was not possible to submit the job. See files in $workdir/output";
            }
        }
    }
    log_info $self->jobs . ' jobs '
        . ( $self->local ? 'executed locally.' : 'submitted to the cluster.' )
        . ' Waiting for confirmation that they started...';
    log_info( "Number of jobs started so far:", { same_line => 1 } );
    my ( $started_now, $started_1s_ago ) = ( 0, 0 );
    while ( $started_now != $self->jobs ) {
        $started_now = () = glob $self->workdir . "/output/*.started";
        if ( $started_now != $started_1s_ago ) {
            log_info( " $started_now", { same_line => 1 } );
            $started_1s_ago = $started_now;
        }
        else {
            sleep(1);
        }
        $self->_check_job_errors;
    }
    log_info "All " . $self->jobs . " jobs started. Waiting for loading scenarios...";
    log_info( "Number of jobs loaded so far:", { same_line => 1 } );
    my ( $loaded_now, $loaded_1s_ago ) = ( 0, 0 );
    while ( $loaded_now != $self->jobs ) {
        $loaded_now = () = glob $self->workdir . "/output/*.loaded";
        if ( $loaded_now != $loaded_1s_ago ) {
            log_info( " $loaded_now", { same_line => 1 } );
            $loaded_1s_ago = $loaded_now;
        }
        else {
            sleep(1);
        }
        $self->_check_job_errors;
    }
    log_info "All " . $self->jobs . " jobs loaded. Waiting for them to be finished...";
    return;
}


sub _delete_jobs_and_exit {
    my ($self) = @_;

    log_info "Deleting jobs: " . join( ', ', @{ $self->sge_job_numbers } );
    foreach my $job ( @{ $self->sge_job_numbers } ) {
        system "qdel $job";
    }
    log_info 'You may want to inspect generated files in ' . $self->workdir . '/output/';
    exit;
}

sub _initialize_replicant {
    my $self = shift;

    # STEP 1 - detect working directory
    $self->set_workdir($ENV{REPLICATOR_WORKDIR});

    # STEP 2 - create message board contact
    my ($message_board_dir) = glob $self->workdir."/*_message_board_*";

    $self->set_message_board(
        Treex::Tool::Parallel::MessageBoard->new(
            current => $self->rid+1,
            workdir => $message_board_dir,
            sharers => $self->jobs + 1,
        )
      );

    $self->message_board({type=>'READY'},0);

}


sub synchronize {
    my $self = shift;

}

sub is_hub {
    my $self = shift;
    return $self->rid == 0;
}




1;
