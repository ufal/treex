package Treex::Core::Run;
use Treex::Moose;
use Treex::Core;
use MooseX::SemiAffordanceAccessor;
with 'MooseX::Getopt';

use Cwd;
use File::Path;
use List::MoreUtils qw(first_index);
use Exporter;
use base 'Exporter';
our @EXPORT = qw(treex);

has 'save' => (
    traits        => ['Getopt'],
    cmd_aliases   => 's',
    is            => 'rw', isa => 'Bool', default => 0,
    documentation => 'save all documents',
);

has 'quiet' => (
    traits      => ['Getopt'],
    cmd_aliases => 'q',
    is          => 'rw', isa => 'Bool', default => 0,
    trigger => sub { Treex::Core::Log::set_error_level('FATAL'); },
    documentation => q{Warning, info and debug messages are surpressed. Only fatal errors are reported.},
);

has 'cleanup' => (
    traits        => ['Getopt'],
    is            => 'rw', isa => 'Bool', default => 0,
    documentation => q{Delete all temporary files.},
);

has 'error_level' => (
    traits      => ['Getopt'],
    cmd_aliases => 'e',
    is          => 'rw', isa => 'ErrorLevel', default => 'INFO',
    trigger => sub { Treex::Core::Log::set_error_level( $_[1] ); },
    documentation => q{Possible error levels: ALL=0, DEBUG=1, INFO=2, WARN=3, FATAL=4},
);

has 'lang' => (
    traits        => ['Getopt'],
    cmd_aliases   => [ 'language', 'L' ],
    is            => 'rw', isa => 'LangCode',
    documentation => q{shortcut for adding "SetGlobal language=xy" at the beginning of the scenario},
);

has 'selector' => (
    traits        => ['Getopt'],
    cmd_aliases   => 'S',
    is            => 'rw', isa => 'Selector',
    documentation => q{shortcut for adding "SetGlobal selector=xy" at the beginning of the scenario},
);

has 'filelist' => (
    traits        => ['Getopt'],
    cmd_aliases   => 'l',
    is            => 'rw', isa => 'Str',
    documentation => 'TODO load a list of treex files from a file',
);

# treex -h should not print "Unknown option: h" before the usage.
has 'help' => (
    traits        => ['Getopt'],
    cmd_aliases   => 'h',
    is            => 'ro', isa => 'Bool', default => 0,
    documentation => q{Print usage info},
);

has 'filenames' => (
    traits        => ['NoGetopt'],
    is            => 'rw',
    isa           => 'ArrayRef[Str]',
    documentation => 'treex file names',
);

has 'glob' => (
    traits        => ['Getopt'],
    cmd_aliases   => 'g',
    is            => 'rw',
    isa           => 'Str',
    documentation => q{Input file mask whose expansion is to Perl, e.g. --glob '*.treex'},
);

has 'scenario' => (
    traits        => ['NoGetopt'],
    is            => 'rw', isa => 'Treex::Core::Scenario',
    documentation => 'scenario object',
);

has 'parallel' => (
    traits        => ['Getopt'],
    cmd_aliases   => 'p',
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => 'Parallelize the task on SGE cluster (using qsub).',
);

has 'jobs' => (
    traits        => ['Getopt'],
    cmd_aliases   => 'j',
    is            => 'ro',
    isa           => 'Int',
    default       => 10,
    documentation => 'Number of jobs for parallelization, default 10. Requires -p.',
);

has 'jobindex' => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa           => 'Int',
    documentation => 'Not to be used manually. If number of jobs is set to J and modulo set to M, only I-th files fulfilling I mod J == M are processed.',
);

has 'outdir' => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa           => 'Str',
    documentation => 'Not to be used manually. Dictory for collecting standard and error outputs in parallelized processing.',
);

has 'qsub' => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa           => 'String',
    documentation => 'Additional parameters passed to qsub. Requires -p.',
);

has 'local' => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa           => 'Bool',
    documentation => 'Run jobs locally (might help with multi-core machines). Requires -p.',
);

has 'command' => (
    is            => 'rw',
    traits        => ['NoGetopt'],
    documentation => 'Command by which treex was executed (if executed from command line)',
);

has 'argv' => (
    is            => 'rw',
    traits        => ['NoGetopt'],
    documentation => 'reference to @ARGV (if executed from command line)',
);

has 'workdir' => (
    is            => 'rw',
    traits        => ['NoGetopt'],
    documentation => 'working directory for temporary files in parallelized processing',
);

has 'sge_job_numbers' => (
    is            => 'rw',
    traits        => ['NoGetopt'],
    documentation => 'list of numbers of jobs executed on sge',
    default       => sub { [] },
);

sub _usage_format {
    return "usage: %c %o scenario [-- treex_files]\nscenario is a sequence of blocks or *.scen files\noptions:";
}

sub BUILD {

    # more complicated tests on consistency of options will be place here
    my ($self) = @_;

    if ( $self->jobindex ) {
        _redirect_output( $self->outdir, 0, $self->jobindex );
    }

    my @file_sources;
    if ( $self->filelist ) {
        push @file_sources, "filelist option";
    }
    if ( $self->filenames ) {
        push @file_sources, "files after --";
    }
    if ( $self->glob ) {
        push @file_sources, "glob option";
    }
    if ( @file_sources > 1 ) {
        log_fatal "At most one way to specify input files can be used. You combined "
            . ( join " and ", @file_sources ) . ".";
    }

    # 'require' can't be changed to 'imply', since the number of jobs has a default value
    if ( ( $self->qsub or $self->jobindex ) and not $self->parallel ) {
        log_fatal "Options --qsub and --jobindex require --parallel";
    }

}

sub execute {
    my ($self) = @_;

    if ( $self->parallel and not defined $self->jobindex ) {
        log_info "Parallelized execution. This process is the head coordinating "
            . $self->jobs . " server processes.";
        $self->_execute_on_cluster();
    }

    # non-parallelized execution, or one of distributed processes
    else {
        if ( $self->parallel ) {
            log_info "Parallelized execution. This process is one out of "
                . $self->jobs . " server processes, jobindex==" . $self->jobindex;
        }
        else {
            log_info "Local (single-process) execution.";
        }
        $self->_execute_locally();
    }

}

my %READER_FOR = (
    treex => 'Treex',
    txt   => 'Text',

    # TODO:
    # conll  => 'Conll',
    # plsgz  => 'Plsgz',
    # treex.gz
    # tmt
);

sub _get_reader_name_for {
    my ( $ext, @extensions ) = map {/[^.]+\.(.+)?/} @_;
    log_fatal 'Files (' . join( ',', @_ ) . ') must have extensions' if !$ext;
    log_fatal 'All files (' . join( ',', @_ ) . ') must have the same extension' if any { $_ ne $ext } @extensions;

    my $r = $READER_FOR{$ext};
    log_fatal "There is no DocumentReader implemented for extension '$ext'" if !$r;
    return "Read::$r";
}

sub _execute_locally {
    my ($self) = @_;
    my $scen_str = join ' ', @{ $self->extra_argv };

    # input data files can be specified in different ways
    if ( $self->glob ) {
        my $mask = $self->glob;
        $mask =~ s/^['"](.+)['"]$/$1/;
        my @files = glob $mask;
        log_fatal 'No files matching mask $mask' if @files == 0;
        $self->set_filenames( \@files );
    }
    elsif ( $self->filelist ) {
        open my $FL, "<:utf8", $self->filelist
            or log_fatal "Cannot open file list " . $self->filelist;
        my @files;
        while (<$FL>) {
            chomp;
            push @files, $_;
        }
        log_fatal 'No files matching mask \'' . $self->glob . '\'\n' if @files == 0;
        $self->set_filenames( \@files );
    }

    # some command line options are just shortcuts for blocks; the blocks are added to the scenario now
    if ( $self->filenames ) {
        my $reader = _get_reader_name_for( @{ $self->filenames } );
        log_info "Block $reader added to the beginning of the scenario.";
        $scen_str = "$reader from=" . join( ',', @{ $self->filenames } ) . " $scen_str";
    }

    if ( $self->save ) {
        log_info "Block Write::Treex added to the end of the scenario.";
        $scen_str .= ' Write::Treex';
    }

    if ( $self->lang ) {
        $scen_str = 'SetGlobal language=' . $self->lang . " $scen_str";
    }

    if ( $self->selector ) {
        $scen_str = 'SetGlobal selector=' . $self->selector . " $scen_str";
    }

    my $scenario = Treex::Core::Scenario->new( { from_string => $scen_str } );

    my $number_of_docs;
    if ( $self->jobindex ) {
        my $reader = $scenario->document_reader;
        $reader->set_jobs( $self->jobs );
        $reader->set_jobindex( $self->jobindex );
        $reader->set_outdir( $self->outdir );

        # If we know the number of documents in advance, inform the cluster head now
        if ( $self->jobindex == 1 ) {
            $number_of_docs = $reader->number_of_documents;

            #log_info "There will be $number_of_docs documents";
            $self->_print_total_documents($number_of_docs);
        }
    }

    $self->set_scenario($scenario);
    $self->scenario->run();

    if ( $self->jobindex && $self->jobindex == 1 && !$number_of_docs ) {
        $number_of_docs = $scenario->document_reader->doc_number;
        # This branch is executed only
        # when the reader does not know number_of_documents in advance.
        # TODO: Why is document_reader->doc_number is one higher than it should be?
        
        #log_info "There were $number_of_docs documents";
        $self->_print_total_documents($number_of_docs);
    }
    return;
}

sub _total_docs_filename {
    my ($self) = @_;
    return $self->outdir . '/filenumber';    #TODO '/total_number_of_documents';
}

sub _print_total_documents {
    my ( $self, $number ) = @_;
    my $filename = $self->_total_docs_filename;
    open my $F, '>', $filename or log_fatal $!;
    print $F $number;
    close $F;
}

sub _create_job_scripts {
    my ($self)      = @_;
    my $current_dir = Cwd::cwd;
    my $workdir     = $self->workdir;
    foreach my $jobnumber ( map { sprintf( "%03d", $_ ) } 1 .. $self->jobs ) {
        my $script_filename = "scripts/job$jobnumber.sh";
        open my $J, ">", "$workdir/$script_filename";
        print $J "#!/bin/bash\n\n";
        print $J "cd $current_dir\n\n";
        print $J "source " . Treex::Core::Config::lib_core_dir()
            . "/../../../../config/init_devel_environ.sh 2> /dev/null\n\n";    # temporary hack !!!
        print $J "echo \$HOSTNAME > $workdir/output/job$jobnumber.init\n";
        print $J "treex --jobindex=$jobnumber --outdir=$workdir/output " . ( join " ", @{ $self->argv } ) .
            " 2>> $workdir/output/job$jobnumber.init\n\n";
        print $J "touch $workdir/output/job$jobnumber.finished\n";
        close $J;
        chmod 0777, "$workdir/$script_filename";
    }
}

sub _run_job_scripts {
    my ($self) = @_;
    my $workdir = $self->workdir;
    foreach my $jobnumber ( 1 .. $self->jobs ) {
        my $script_filename = "scripts/job" . sprintf( "%03d", $jobnumber ) . ".sh";

        if ( $self->local ) {
            log_info "$workdir/$script_filename executed locally";
            system "$workdir/$script_filename &";
        }
        else {
            log_info "$workdir/$script_filename submitted to the cluster";

            open my $QSUB, "cd $workdir && qsub -cwd -e output/ -S /bin/bash $script_filename |";

            my $firstline = <$QSUB>;
            chomp $firstline;
            if ( $firstline =~ /job (\d+)/ ) {
                push @{ $self->sge_job_numbers }, $1;
            }
            else {
                log_fatal 'Job number not detected after the attempt at submitting the job. ' .
                    'Perhaps it was not possible to submit the job. See files in $workdir/output';
            }
        }
    }

    log_info "Waiting for all jobs to be started...";
    while ( ( scalar( () = glob $self->workdir . "/output/*.init" ) ) < $self->jobs ) {
        sleep(1);
    }
    log_info "All " . $self->jobs . " jobs started. Waiting for them to be finished...";
    return;
}

sub _wait_for_jobs {
    my ($self) = @_;
    my $current_file_number = 1;
    my $total_file_number;
    my $all_finished;
    my $filenumber_file = $self->workdir . "/output/filenumber";

    WAIT_LOOP:
    while ( not defined $total_file_number or $current_file_number <= $total_file_number ) {

        if ( not defined $total_file_number and -f $filenumber_file ) {
            open( my $N, $filenumber_file );
            $total_file_number = <$N>;
            log_info "Total number of documents to be processed: $total_file_number";
        }

        $all_finished ||= ( scalar( () = glob $self->workdir . "/output/job???.finished" ) == $self->jobs );
        my $current_finished = (
            $all_finished ||
                ( glob $self->workdir . "/output/job*file-" . sprintf( "%07d", $current_file_number ) . ".finished" )    #TODO: tenhle soubor se nikdy nevytvari
        );

        if ($current_finished) {
            log_info "Document $current_file_number out of " .
                ( defined $total_file_number ? $total_file_number : '?' ) . " finished.";

            foreach my $stream (qw(stderr stdout)) {
                my $mask = $self->workdir . "/output/job*-file" . sprintf( "%07d", $current_file_number ) . "*.$stream";
                my ($filename) = glob $mask;

                if ( !defined $filename ) {
                    log_fatal "Document $current_file_number finished without $mask output";

                    #sleep 1;
                    #next WAIT_LOOP;
                }
                my ($jobnumber) = ( $filename =~ /job(...)/ );

                open my $FILE, '<:utf8', $filename or log_fatal $!;
                if ( $stream eq "stdout" ) {
                    print $_ while <$FILE>;
                }
                else {
                    print STDERR "job$jobnumber: $_" while <$FILE>;
                }
            }
            $current_file_number++;
        }

        else {
            sleep 1;
        }
    }
}

sub _execute_on_cluster {
    my ($self) = @_;

    # create working directory
    my $counter;
    my $directory;
    do {
        $counter++;
        $directory = sprintf "%03d-cluster-run", $counter;
        }
        while ( -d $directory );
    $self->set_workdir($directory);
    log_info "Creating working directory $directory";
    mkdir $directory or log_fatal $!;
    foreach my $subdir (qw(output scripts)) {
        mkdir "$directory/$subdir" or log_fatal $!;
    }

    # catching Ctrl-C interruption
    $SIG{INT} =
        sub {
        log_info "Caught Ctrl-C, all jobs will be interrupted";
        foreach my $job ( @{ $self->sge_job_numbers } ) {
            log_info "Deleting job $job";
            system "qdel $job";
        }
        log_info "You may want to inspect generated files in $directory/output";
        exit;
        };

    $self->_create_job_scripts();
    $self->_run_job_scripts();

    STDOUT->autoflush(1);
    STDERR->autoflush(1);

    $self->_wait_for_jobs();

    log_info "All jobs finished.";

    if ( $self->cleanup ) {
        log_info "Deleting the directory with temporary files $directory";
        rmtree $directory or log_fatal $!;
    }
}

sub _redirect_output {
    my ( $outdir, $filenumber, $jobindex ) = @_;

    my $stem = $outdir . "/job" . sprintf( "%03d", $jobindex + 0 ) . "-file" . sprintf( "%07d", $filenumber );
    open OUTPUT, '>', "$stem.stdout" or die $!;    # where will these messages go to, before redirection?
    open ERROR,  '>', "$stem.stderr" or die $!;
    STDOUT->fdopen( \*OUTPUT, 'w' ) or die $!;
    STDERR->fdopen( \*ERROR,  'w' ) or die $!;
    STDOUT->autoflush(1);
}

# not a method !
sub treex {
    my $arguments = shift;                         # ref to array of arguments, or a string containing all arguments as on the command line

    if ( ref($arguments) eq "ARRAY" ) {

        @ARGV = map {                              # dirty!!!, god knows why spaces in arguments are not processed correctly if they come from command line
            if (/^(\S+=)(.+ .+)$/) {
                split( / /, "$1'$2'" );
            }
            else {
                $_;
            }
        } @$arguments;

        my $idx = first_index { $_ eq '--' } @ARGV;
        my %args;
        $args{command}   = join " ", @ARGV;
        $args{argv}      = \@ARGV;
        $args{filenames} = [ splice @ARGV, $idx + 1 ] if $idx != -1;
        my $app = Treex::Core::Run->new_with_options( \%args );
        $app->execute();

    }

    elsif ( defined $arguments ) {
        treex( [ grep {$_} split( /\s/, $arguments ) ] );
    }

    else {
        log_fatal "Unspecified arguments for running treex.";
    }
}

1;
