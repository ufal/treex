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
    documentation => q{Possible values: ALL, DEBUG, INFO, WARN, FATAL},
);

has 'forward_error_level' => (
    traits        => ['Getopt'],
    cmd_aliases   => 'E',
    is            => 'rw', isa => 'ErrorLevel', default => 'WARN',
    documentation => q{messages with this level or higher will be forwarded from the distributed jobs to the main STDERR},
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
#has 'help' => (
#    traits        => ['Getopt'],
#    cmd_aliases   => 'h',
#    is            => 'ro', isa => 'Bool', default => 0,
#    documentation => q{Print usage info},
#);

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
    isa           => 'Str',
    documentation => 'Additional parameters passed to qsub. Requires -p.',
);

has 'local' => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa           => 'Bool',
    documentation => 'Run jobs locally (might help with multi-core machines). Requires -p.',
);

has 'watch' => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa           => 'Str',
    documentation => 're-run when the given file is changed TODO better doc',
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
    my $done = 0;
    my $time;
    my $watch = $self->watch;
    
    if (defined $watch){        
        log_fatal "Watch file $watch does not exists" if ! -f $watch;
        $time = (stat $watch)[9];
    }

    while ( !$done ) {
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

        $done = 1;
        my $info_written = 0;
        WATCH_CHANGE:
        while (defined $watch && -f $watch){
            my $new_time = (stat $watch)[9];
            if ($new_time > $time){
                $time = $new_time;
                $done = 0;
                last WATCH_CHANGE;
            }
            if (!$info_written){
                log_info "Watchin '$watch' file. Touch it to re-run, delete to quit.";
                $info_written = 1;
            }
            sleep 1;
        }
    }
    return;
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
        log_fatal "No files matching mask $mask" if @files == 0;
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

    my $scenario = $self->scenario;
    if (!defined $scenario){
        $scenario = Treex::Core::Scenario->new( { from_string => $scen_str } );
    } else {
        $scenario->reset();
    }
    

    my $number_of_docs;
    if ( $self->jobindex ) {
        open my $F, '>', $self->outdir . sprintf( "/job%03d.loaded", $self->jobindex );
        close $F;
        my $reader = $scenario->document_reader;
        $reader->set_jobs( $self->jobs );
        $reader->set_jobindex( $self->jobindex );
        $reader->set_outdir( $self->outdir );

        # If we know the number of documents in advance, inform the cluster head now
        if ( $self->jobindex == 1 ) {
            $number_of_docs = $reader->number_of_documents;

            #log_info "There will be $number_of_docs documents";
            $self->_write_total_doc_number($number_of_docs);
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
        $self->_write_total_doc_number($number_of_docs);
    }
    return;
}

# This is called by distributed jobs (they don't have $self->workdir)
sub _write_total_doc_number {
    my ( $self, $number ) = @_;
    my $filename = $self->outdir . '/total_number_of_documents';
    open my $F, '>', $filename or log_fatal $!;
    print $F $number;
    close $F;
}

# This is called by the main treex (it doesn't have $self->outdir)
sub _read_total_doc_number {
    my ($self) = @_;
    my $total_doc_number_file = $self->workdir . "/output/total_number_of_documents";
    if ( -f $total_doc_number_file ) {
        open( my $N, $total_doc_number_file ) or log_fatal $!;
        my $total_file_number = <$N>;
        log_info "Total number of documents to be processed: $total_file_number";
        return $total_file_number;
    }
    else {
        return undef;
    }
}

sub _create_job_scripts {
    my ($self)      = @_;
    my $current_dir = Cwd::cwd;
    my $workdir     = $self->workdir;
    foreach my $jobnumber ( map { sprintf( "%03d", $_ ) } 1 .. $self->jobs ) {
        my $script_filename = "scripts/job$jobnumber.sh";
        open my $J, ">", "$workdir/$script_filename";
        print $J "#!/bin/bash\n\n";
        print $J "echo \$HOSTNAME > $current_dir/$workdir/output/job$jobnumber.started\n";
        print $J "cd $current_dir\n\n";
        print $J "source " . Treex::Core::Config::lib_core_dir()
            . "/../../../../config/init_devel_environ.sh 2> /dev/null\n\n";    # temporary hack !!!

        # TODO: if the original line contains -- file.treex, this doesn't work
        print $J "treex --jobindex=$jobnumber --outdir=$workdir/output "
            . ( join " ", @{ $self->argv } )
            . " 2>> $workdir/output/job$jobnumber.started\n\n";
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
            system "$workdir/$script_filename &";
        }
        else {
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
    log_info $self->jobs . ' jobs '
        . ( $self->local ? 'executed locally.' : 'submitted to the cluster.' )
        . ' Waiting for confirmation that they started...';
    log_info( "Number of jobs started so far:", { same_line => 1 } );
    my ( $started_now, $started_1s_ago ) = ( 0, 0 );
    while ( $started_now != $self->jobs ) {
        $started_now = scalar( () = glob $self->workdir . "/output/*.started" );
        if ( $started_now != $started_1s_ago ) {
            log_info( " $started_now", { same_line => 1 } );
            $started_1s_ago = $started_now;
        }
        else {
            sleep(1);
        }
    }
    log_info "All " . $self->jobs . " jobs started. Waiting for loading scenarios...";

    log_info( "Number of jobs loaded so far:", { same_line => 1 } );
    my ( $loaded_now, $loaded_1s_ago ) = ( 0, 0 );
    while ( $loaded_now != $self->jobs ) {
        $loaded_now = scalar( () = glob $self->workdir . "/output/*.loaded" );
        if ( $loaded_now != $loaded_1s_ago ) {
            log_info( " $loaded_now", { same_line => 1 } );
            $loaded_1s_ago = $loaded_now;
        }
        else {
            sleep(1);
        }
    }
    log_info "All " . $self->jobs . " jobs loaded. Waiting for them to be finished...";
    return;
}

sub _print_output_files {
    my ( $self, $doc_number ) = @_;
    foreach my $stream (qw(stderr stdout)) {
        my $mask = $self->workdir . "/output/job*-doc" . sprintf( "%07d", $doc_number ) . ".$stream";
        my ($filename) = glob $mask;

        if ( !defined $filename ) {
            log_fatal "Document $doc_number finished without producing $mask";
        }

        open my $FILE, '<:utf8', $filename or log_fatal $!;
        if ( $stream eq "stdout" ) {
            print $_ while <$FILE>;
        }
        else {
            my ($jobnumber) = ( $filename =~ /job(...)/ );
            my $report = $self->forward_error_level;
            while (<$FILE>) {

                #TODO: better implementation
                # $Treex::Core::Log::ERROR_LEVEL_VALUE{$report} doesn't work
                my ( undef, $level ) = /^(TMT|TREEX)-(DEBUG|INFO|WARN|FATAL)/;
                next if $level =~ /^D/ && $report !~ /^[AD]/;
                next if $level =~ /^I/ && $report !~ /^[ADI]/;
                next if $level =~ /^W/ && $report !~ /^[ADIW]/;
                print STDERR "job$jobnumber: $_";
            }
        }
    }
    return;
}

sub _doc_started {
    my ( $self, $doc_number ) = @_;
    my $mask = $self->workdir . sprintf( '/output/job*-doc%07d.stderr', $doc_number );

    # Note that return glob $mask; does not work
    # glob in scalar context iterates over files,
    # so if the file was already "iterated", it return undef.
    my @filenames = glob($mask);
    return scalar @filenames;
}

sub _wait_for_jobs {
    my ($self)              = @_;
    my $current_doc_number  = 1;
    my $current_doc_started = 0;
    my $total_doc_number    = 0;
    my $all_jobs_finished   = 0;
    my $done                = 0;

    while ( !$done ) {
        $total_doc_number    ||= $self->_read_total_doc_number();
        $all_jobs_finished   ||= ( scalar( () = glob $self->workdir . "/output/job???.finished" ) == $self->jobs );
        $current_doc_started ||= $self->_doc_started($current_doc_number);

        # If a job starts processing another doc,
        # it means it has finished the current doc.
        my $current_doc_finished = $all_jobs_finished;
        $current_doc_finished ||= $self->_doc_started( $current_doc_number + $self->jobs );

        if ($current_doc_finished) {
            $self->_print_output_files($current_doc_number);
            $current_doc_number++;
            $current_doc_started = 0;
        }
        else {
            sleep 1;
        }

        # Both of the conditions below are necessary.
        # - $total_doc_number might be unknown (i.e. 0) before all_jobs_finished
        # - even if all_jobs_finished, we must wait for forwarding all output files
        # Note that if $current_doc_number == $total_doc_number,
        # the output of the last doc was not forwarded yet.
        $done = $all_jobs_finished && $current_doc_number > $total_doc_number;
    }
    return;
}

sub _execute_on_cluster {
    my ($self) = @_;

    # create working directory
    my $counter;
    my $directory;
    do {
        $counter++;
        $directory = sprintf "%03d-cluster-run", $counter;

        # TODO There is a strange problem when executing e.g.
        #  for i in `seq 4`; do treex/bin/t/qparallel.t; done
        # where qparallel.t executes treex -p --cleanup ...
        # I don't know the real cause of the bug, but as a workaround
        # you can omit --cleanup or uncomment next line
        # $directory .= sprintf "%03d-cluster-run", rand 1000;
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
    my ( $outdir, $docnumber, $jobindex ) = @_;
    my $job = sprintf( 'job%03d', $jobindex + 0 );
    my $doc = $docnumber ? sprintf( "doc%07d", $docnumber ) : 'loading';
    my $stem = "$outdir/$job-$doc";
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

__END__

--watch option

SYNOPSIS:
touch timestamp.file
treex --watch=timestamp.file my.scen & # or without & and open another terminal
# after all documents are processed, treex is still running, watching timestamp.file
# you can modify any modules/blocks and then
touch timestamp.file
# All modified modules will be reloaded (the number of reloaded modules is printed).
# The document reader is reset, so it starts reading the first file again.
# To exit this "watching loop" either rm timestamp.file or press Ctrl^C.

BENEFITS:
* much faster development cycles (e.g. most time of en-cs translation is spent on loading)
* Now I have some non-deterministic problems with loading NER::Stanford
  - using --watch I get it loaded on all jobs once and then I don't have to reload it.

TODO:
* modules are just reloaded, no constructors are called yet
* not tested on cluster yet (but it should work there)
