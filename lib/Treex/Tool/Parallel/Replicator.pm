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


    # STEP 5 - wait until all jobs are ready

}

sub _create_job_scripts { # mostly copied from Treex::Core::Run
    my ($self)      = @_;
    my $current_dir = Cwd::cwd;
    my $workdir     = $self->workdir;
    mkdir $self->workdir."/scripts" or log_fatal $!;
    foreach my $jobnumber ( map { sprintf( "%03d", $_ ) } 1 .. $self->jobs ) {
        my $script_filename = "scripts/job$jobnumber.sh";
        open my $J, ">", "$workdir/$script_filename" or log_fatal $!;
        print $J "#!/bin/bash\n\n";
        print $J "echo \$HOSTNAME > $current_dir/$workdir/output/job$jobnumber.started\n";
        print $J "export PATH=/opt/bin/:\$PATH > /dev/null 2>&1\n\n";
        print $J "cd $current_dir\n\n";
        print $J "source " . Treex::Core::Config->lib_core_dir()
            . "/../../../../config/init_devel_environ.sh 2> /dev/null\n\n";    # temporary hack !!!

        my $opts_and_scen = join ' ', map { _quote_argument($_) } @{ $self->ARGV };
        if ( $self->filenames ) {
            $opts_and_scen .= ' -- ' . join ' ', map { _quote_argument($_) } @{ $self->filenames };
        }
        # tady bude spusteni stejneho skriptu
#        print $J "treex --jobindex=$jobnumber --outdir=$workdir/output $opts_and_scen"
            . " 2>> $workdir/output/job$jobnumber.started\n\n";
        print $J "touch $workdir/output/job$jobnumber.finished\n";
        close $J;
        chmod 0777, "$workdir/$script_filename";
    }
    return;
}



sub _initialize_replicant {
    my $self = shift;

    # STEP 1 - detect working directory
    $self->set_workdir($ENV{REPLICATOR_WORKDIR});

    # STEP 2 - create message board contact
    my ($message_board_dir) = glob $self->workdir/."*_message_board_*";

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
