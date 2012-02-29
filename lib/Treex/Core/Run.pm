package Treex::Core::Run;
use 5.008;
use Moose;
use Treex::Core::Common;
use Treex::Core;
use MooseX::SemiAffordanceAccessor 0.09;
with 'MooseX::Getopt';

use Cwd;
use File::Path;
use File::Temp qw(tempdir);
use File::Which;
use List::MoreUtils qw(first_index);
use IO::Interactive;
use Exporter;
use base 'Exporter';
our @EXPORT_OK = q(treex);

has 'save' => (
    traits        => ['Getopt'],
    cmd_aliases   => 's',
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => 'save all documents',
);

has 'quiet' => (
    traits        => ['Getopt'],
    cmd_aliases   => 'q',
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    trigger       => sub { Treex::Core::Log::log_set_error_level('FATAL'); },
    documentation => q{Warning, info and debug messages are suppressed. Only fatal errors are reported.},
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
    trigger => sub { Treex::Core::Log::log_set_error_level( $_[1] ); },
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
    is            => 'rw', isa => 'Treex::Type::LangCode',
    documentation => q{shortcut for adding "Util::SetGlobal language=xy" at the beginning of the scenario},
);

has 'selector' => (
    traits        => ['Getopt'],
    cmd_aliases   => 'S',
    is            => 'rw', isa => 'Treex::Type::Selector',
    documentation => q{shortcut for adding "Util::SetGlobal selector=xy" at the beginning of the scenario},
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
    is            => 'rw',
    isa           => 'Treex::Core::Scenario',
    predicate     => '_has_scenario',
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

has 'local' => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa           => 'Bool',
    documentation => 'Run jobs locally (might help with multi-core machines). Requires -p.',
);

has 'priority' => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa           => 'Int',
    default       => -100,
    documentation => 'Priority for qsub, an integer in the range -1023 to 0 (or 1024 for admins), default=-100. Requires -p.',
);

has 'mem' => (
    traits        => ['Getopt'],
    cmd_aliases   => [ 'm', 'memory' ],
    is            => 'ro',
    isa           => 'Str',
    default       => '2G',
    documentation => 'How much memory should be allocated for cluster jobs, default=2G. Requires -p. '
        . 'Translates to "qsub -hard -l mem_free=$mem -l act_mem_free=$mem -l h_vmem=$mem".',
);

has 'qsub' => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa           => 'Str',
    default       => '',
    documentation => 'Additional parameters passed to qsub. Requires -p. See --priority and --mem.',
);

has 'watch' => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa           => 'Str',
    documentation => 're-run when the given file is changed TODO better doc',
);

has 'workdir' => (
    is            => 'rw',
    traits        => ['Getopt'],
    isa           => 'Str',
    documentation => 'working directory for temporary files in parallelized processing ' .
        '(if not specified, directories such as 001-cluster-run, 002-cluster-run etc. are created)',
);

has 'sge_job_numbers' => (
    is            => 'rw',
    traits        => ['NoGetopt'],
    documentation => 'list of numbers of jobs executed on sge',
    default       => sub { [] },
);

has 'dump_scenario' => (
    traits        => ['Getopt'],
    cmd_aliases   => 'd',
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => 'Just dump (print to STDOUT) the given scenario and exit.',
);

has 'survive' => (
    traits        => ['Getopt'],
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => 'Continue collecting jobs\' outputs even if some of them crashed (risky, use with care!).',
);

has version => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa           => 'Bool',
    default       => 0,
    cmd_aliases   => 'v',
    documentation => q(Print treex and perl version),
    trigger       => sub {
        print get_version();
        exit();
    },
);

sub _usage_format {
    return "usage: %c %o scenario [-- treex_files]\nscenario is a sequence of blocks or *.scen files\noptions:";
}

#gets info about version of treex and perl
sub get_version {
    my $perl_v  = $^V;
    my $perl_x  = $^X;
    my $treex_v = $Treex::Core::Run::VERSION || 'DEV';
    my $treex_x = which('treex');

    # File::Which::which sometimes fails to found treex.
    if ( !defined $treex_x ) {
        chomp( $treex_x = `which treex 2> /dev/null` );
        $treex_x ||= '<treex not found in $PATH>';
    }
    my $version_string = <<"VERSIONS";
Treex version: $treex_v from $treex_x
Perl version: $perl_v from $perl_x
VERSIONS
    return $version_string;
}

sub BUILD {

    # more complicated tests on consistency of options will be place here
    my ($self) = @_;
    if ( $self->jobindex ) {
        _redirect_output( $self->outdir, 0, $self->jobindex );
    }

    my @file_sources;
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
    if ( ( $self->qsub || $self->jobindex ) && !$self->parallel ) {
        log_fatal "Options --qsub and --jobindex require --parallel";
    }
    return;
}

sub _execute {
    my ($self) = @_;
    if ( $self->dump_scenario ) {

        # TODO: execute_locally does the same work as the following line in a more safe ways
        # (If someone wants to run treex -d My::Block my_scen.scen)
        my $scen_str = join ' ', @{ $self->extra_argv };
        $self->set_scenario( Treex::Core::Scenario->new( scenario_string => $scen_str, runner => $self ) );

        # TODO: Do it properly - perhaps, add a Scenario option to not load all the blocks.
        # We cannot create the real scenario instance without loading all the blocks
        # However, since r6307 some Scenario's functions were changed to methods, so we must create a dummy instance.

        #my @block_items = Treex::Core::Scenario::parse_scenario_string($scen_str);
        #my @block_items = $dummy_scenario->parse_scenario_string($scen_str);

        print "# Full Scenario generated by 'treex --dump_scenario' on " . localtime() . "\n";
        print $self->scenario->construct_scenario_string( multiline => 1 ), "\n";
        exit;
    }

    my $done = 0;
    my $time;
    my $watch = $self->watch;

    if ( defined $watch ) {
        log_fatal "Watch file '$watch' does not exists" if !-f $watch;
        $time = ( stat $watch )[9];
    }

    while ( !$done ) {
        if ( $self->parallel && !defined $self->jobindex ) {
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
        while ( defined $watch && -f $watch ) {
            my $new_time = ( stat $watch )[9];
            if ( $new_time > $time ) {
                $time = $new_time;
                $done = 0;
                last WATCH_CHANGE;
            }
            if ( !$info_written ) {
                log_info "Watching '$watch' file. Touch it to re-run, delete to quit.";
                $info_written = 1;
            }
            sleep 1;
        }
    }
    return;
}

my %READER_FOR = (
    'treex'    => 'Treex',
    'treex.gz' => 'Treex',
    'txt'      => 'Text',
    'txt.gz'   => 'Text',
    'streex'   => 'Treex',
    'mrg'      => 'PennMrg',
    'mrg.gz'   => 'PennMrg',

    # TODO:
    # conll  => 'Conll',
    # plsgz  => 'Plsgz',
    # tmt
);

sub _get_reader_name_for {
    my $self    = shift;
    my @names   = @_;
    my $base_re = join( '|', keys %READER_FOR );
    my $re      = qr{\.($base_re)$};
    my @extensions;
    my $first;

    foreach my $name (@names) {
        if ( $name =~ /$re/ ) {
            my $current = $1;
            $current =~ s/\.gz$//;
            if ( !defined $first ) {
                $first = $current;
            }
            log_fatal 'All files (' . join( ',', @names ) . ') must have the same extension' if ( $current ne $first );
            push @extensions, $current;
        }
        else {
            log_fatal 'Files (' . join( ',', @names ) . ') must have extensions';
        }
    }
    my $r = $READER_FOR{$first};
    log_fatal "There is no DocumentReader implemented for extension '$first'" if !$r;
    return "Read::$r";
}

sub _execute_locally {
    my ($self) = @_;

    # Parameters can contain whitespaces that should be preserved
    my @arguments;
    foreach my $arg ( @{ $self->extra_argv } ) {
        if ( $arg =~ /(\S+)=(.*\s.*)$/ ) {
            my ( $name, $value ) = ( $1, $2 );
            $value =~ s/'/\\'/g;
            push @arguments, qq($name='$value');
        }
        else {
            push @arguments, $arg;
        }
    }
    my $scen_str = join ' ', @arguments;

    # input data files can be specified in different ways
    if ( $self->glob ) {
        my $mask = $self->glob;
        $mask =~ s/^['"](.+)['"]$/$1/;
        my @files = glob $mask;
        log_fatal "No files matching mask $mask" if @files == 0;
        $self->set_filenames( \@files );
    }

    # some command line options are just shortcuts for blocks; the blocks are added to the scenario now
    if ( $self->filenames ) {
        my $reader = $self->_get_reader_name_for( @{ $self->filenames } );
        log_info "Block $reader added to the beginning of the scenario.";
        $scen_str = "$reader from=" . join( ',', @{ $self->filenames } ) . " $scen_str";
    }

    if ( $self->save ) {
        log_info "Block Write::Treex clobber=1 added to the end of the scenario.";
        $scen_str .= ' Write::Treex clobber=1';
    }

    if ( $self->lang ) {
        $scen_str = 'Util::SetGlobal language=' . $self->lang . " $scen_str";
    }

    if ( $self->selector ) {
        $scen_str = 'Util::SetGlobal selector=' . $self->selector . " $scen_str";
    }

    my $loading_started = time;
    if ( $self->_has_scenario ) {
        $self->scenario->restart();
    }
    else {
        $self->set_scenario( Treex::Core::Scenario->new( from_string => $scen_str, runner => $self ) );
        $self->scenario->load_blocks;
    }
    my $scenario      = $self->scenario;
    my $loading_ended = time;
    log_info "Loading the scenario took " . ( $loading_ended - $loading_started ) . " seconds";

    my $number_of_docs;
    if ( $self->jobindex ) {
        my $fn = $self->outdir . sprintf( "/job%03d.loaded", $self->jobindex );
        open my $F, '>', $fn or log_fatal "Cannot open file $fn";
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

    $scenario->run();
    log_info "Running the scenario took " . ( time - $loading_ended ) . " seconds";

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
    return;
}

# This is called by the main treex (it doesn't have $self->outdir)
sub _read_total_doc_number {
    my ($self) = @_;
    my $total_doc_number_file = $self->workdir . "/output/total_number_of_documents";
    if ( -f $total_doc_number_file ) {
        open( my $N, '<', $total_doc_number_file ) or log_fatal $!;
        my $total_file_number = <$N>;
        close $N;
        if ( defined $total_file_number ) {
            log_info "Total number of documents to be processed: $total_file_number";
        }
        return $total_file_number;
    }
    else {
        return;
    }
}

sub _quote_argument {
    my $arg = shift;
    $arg =~ s/([\`\\\"\$])/\\$1/g;
    return '"' . $arg . '"';
}

sub _create_job_scripts {
    my ($self)      = @_;
    my $current_dir = Cwd::cwd;
    my $workdir     = $self->workdir;

    # If there is some stdin piped to treex we must save it to a file
    # and redirect it to the jobs.
    # You cannot use interactive input from terminal to "treex -p".
    # (If you really need it, use perl -npe 1 | treex -p ...)
    my $input = '';
    if ( !IO::Interactive::is_interactive(*STDIN) ) {
        my $stdin_file = "$workdir/input";
        $input = "cat $stdin_file | ";
        ## no critic (ProhibitExplicitStdin)
        open my $TEMP, '>', $stdin_file or log_fatal("Cannot create file $stdin_file to store input: $!");
        while (<STDIN>) {
            print $TEMP $_;
        }
        close $TEMP;
    }

    foreach my $jobnumber ( map { sprintf( "%03d", $_ ) } 1 .. $self->jobs ) {
        my $script_filename = "scripts/job$jobnumber.sh";
        open my $J, ">", "$workdir/$script_filename" or log_fatal $!;
        print $J "#!/bin/bash\n\n";
        print $J 'echo -e "$HOSTNAME\n"`date +"%s"` > ' . ( $workdir =~ /^\// ? $workdir : "$current_dir/$workdir" )
            . "/output/job$jobnumber.started\n";
        print $J "export PATH=/opt/bin/:\$PATH > /dev/null 2>&1\n\n";
        print $J "cd $current_dir\n\n";
        print $J "source " . Treex::Core::Config->lib_core_dir()
            . "/../../../../config/init_devel_environ.sh 2> /dev/null\n\n";    # temporary hack !!!

        my $opts_and_scen = join ' ', map { _quote_argument($_) } @{ $self->ARGV };
        if ( $self->filenames ) {
            $opts_and_scen .= ' -- ' . join ' ', map { _quote_argument($_) } @{ $self->filenames };
        }
        print $J $input . "treex --jobindex=$jobnumber --workdir=$workdir --outdir=$workdir/output $opts_and_scen"
            . " 2>> $workdir/output/job$jobnumber.started\n\n";
        print $J "date +'%s' > $workdir/output/job$jobnumber.finished\n";
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
            my $mem       = $self->mem;
            my $qsub_opts = '-cwd -e output/ -S /bin/bash';
            $qsub_opts .= " -hard -l mem_free=$mem -l act_mem_free=$mem -l h_vmem=$mem";
            $qsub_opts .= ' -p ' . $self->priority;
            $qsub_opts .= ' ' . $self->qsub;

            open my $QSUB, "cd $workdir && qsub $qsub_opts $script_filename |" or log_fatal $!;    ## no critic (ProhibitTwoArgOpen)

            my $firstline = <$QSUB>;
            close $QSUB;
            chomp $firstline if ( defined $firstline );
            if ( defined $firstline && $firstline =~ /job (\d+)/ ) {
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

        # $count = () = some_function();
        # This is a Perl idiom (see e.g. page 32 of Modern Perl)
        # for counting the number of elements returned by some_function()
        # without using a temporary variable. It's useful when the function
        # called in scalar context does not return the number of elements
        # that would be returned when called in list context.
        # And this is the case of glob which iterates in scalar context.
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

# Prints error messages from the output of the current document processing.
sub _print_output_files {
    my ( $self, $doc_number ) = @_;

    foreach my $stream (qw(stderr stdout)) {
        my $mask = $self->workdir . "/output/job*-doc" . sprintf( "%07d", $doc_number ) . ".$stream";
        my ($filename) = glob $mask;
        if ( !defined $filename ) {
            my $message = "Document $doc_number finished without producing $mask . " .
                " It might be useful to inspect " . $self->workdir . "/output/job*-loading.stderr";
            if ( $self->survive ) {
                log_warn("$message (fatal error ignored due to survival mode, be careful)");
                return;
            }
            else {
                log_fatal $message;
            }
        }

        open my $FILE, '<:encoding(utf8)', $filename or log_fatal $!;
        if ( $stream eq "stdout" ) {
            while (<$FILE>) {
                print;
            }
        }
        else {
            my ($jobnumber) = ( $filename =~ /job(...)/ );
            my $report      = $self->forward_error_level;
            my $success     = 0;
            while (<$FILE>) {

                # skip [success] indicatory lines, but set the success flag to 1
                if ( $_ =~ /^Document [0-9]+\/[0-9\?]+ .*: \[success\]\.\r?\n?$/ ) {
                    $success = 1;
                    next;
                }

                #TODO: better implementation
                # $Treex::Core::Log::ERROR_LEVEL_VALUE{$report} doesn't work
                my ($level) = /^TREEX-(DEBUG|INFO|WARN|FATAL)/;
                $level ||= '';
                next if $level =~ /^D/ && $report !~ /^[AD]/;
                next if $level =~ /^I/ && $report !~ /^[ADI]/;
                next if $level =~ /^W/ && $report !~ /^[ADIW]/;
                print STDERR "job$jobnumber: $_";
            }

            # test for the [success] indication on the last line of STDERR
            if ( !$success ) {
                log_fatal "Document $doc_number has not finished successfully (see $filename)";
            }
        }
        close $FILE;
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

        $self->_check_job_errors;

        # Both of the conditions below are necessary.
        # - $total_doc_number might be unknown (i.e. 0) before all_jobs_finished
        # - even if all_jobs_finished, we must wait for forwarding all output files
        # Note that if $current_doc_number == $total_doc_number,
        # the output of the last doc was not forwarded yet.
        $done = $all_jobs_finished && $current_doc_number > $total_doc_number;
    }
    return;
}

sub _print_execution_time {
    my ($self) = @_;

    my $time_total = 0;

    my %hosts = ();

    # read job log files
    for my $file_finished ( glob $self->workdir . "/output/job???.finished" ) {

        # derivate file name
        my $file_started = $file_finished;
        $file_started =~ s/finished/started/;

        # retrieve start time
        open( my $fh_started, "<", $file_started ) or log_fatal $!;
        my $hostname = <$fh_started>;
        chomp $hostname;
        my $time_start = <$fh_started>;
        close($fh_started);

        # retrieve finish time
        open( my $fh_finished, "<", $file_finished ) or log_fatal $!;
        my $time_finish = <$fh_finished>;
        close($fh_finished);

        # increase total time
        $time_total += ( $time_finish - $time_start );
        $hosts{$hostname}{'time'} += ( $time_finish - $time_start );
        $hosts{$hostname}{'c'}++;
    }

    # find the slowest and the fastest machine
    my $min_time = $time_total;
    my $min_host = "";
    my $max_time = 0;
    my $max_host = 0;

    for my $host ( keys %hosts ) {
        my $avg = $hosts{$host}{'time'} / $hosts{$host}{'c'};
        if ( $avg < $min_time ) {
            $min_time = $avg;
            $min_host = $host;
        }

        if ( $avg > $max_time ) {
            $max_time = $avg;
            $max_host = $host;
        }
    }

    # print out statistics
    log_info "Total execution time: $time_total";
    log_info "Execution time per job: " . sprintf( "%0.3f", $time_total / $self->jobs );
    log_info "Slowest machine: $max_host = $max_time";
    log_info "Fastest machine: $min_host = $min_time";

    return;
}

# To get utf8 encoding also when using qx (aka backticks):
# my $command_output = qw($command);
# we need to
use open qw{ :std IO :encoding(UTF-8) };

sub _check_job_errors {
    my ($self) = @_;
    my $workdir = $self->workdir;
    if ( defined( my $fatal_name = glob "$workdir/output/*fatalerror" ) ) {
        log_info "At least one job crashed with fatal error ($fatal_name).";
        my ($fatal_job) = $fatal_name =~ /job(\d+)/;
        my $command     = "grep -h -A 10 -B 25 FATAL $workdir/output/job$fatal_job*.stderr";
        my $fatal_lines = qx($command);
        log_info "********************** FATAL ERRORS FOUND IN JOB $fatal_job ******************\n";
        log_info "$fatal_lines\n";
        log_info "********************** END OF JOB $fatal_job FATAL ERRORS LOG ****************\n";
        if ( $self->survive ) {
            log_warn("fatal error ignored due to the --survive option, be careful");
            return;
        }
        else {
            log_info "All remaining jobs will be interrupted now.";
            $self->_delete_jobs_and_exit;
        }
    }
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

sub _execute_on_cluster {
    my ($self) = @_;

    # create working directory, if not specified as a command line option
    if ( not defined $self->workdir ) {
        my $counter;
        my $directory_prefix;
        my @existing_dirs;
        do {
            $counter++;
            $directory_prefix = sprintf "%03d-cluster-run-", $counter;

            # TODO There is a strange problem when executing e.g.
            #  for i in `seq 4`; do treex/bin/t/qparallel.t; done
            # where qparallel.t executes treex -p --cleanup ...
            # I don't know the real cause of the bug, but as a workaround
            # you can omit --cleanup or uncomment next line
            # $directory .= sprintf "%03d-cluster-run", rand 1000;
            #            print STDERR "XXXX tested prefix $directory_prefix:".(join ' ', glob("$directory_prefix*"))."\n";
            @existing_dirs = glob "$directory_prefix*";    # separate var because of troubles with glob context
            }
            while (@existing_dirs);
        my $directory = tempdir "${directory_prefix}XXXXX" or log_fatal($!);
        $self->set_workdir($directory);
        log_info "Working directory $directory created";

        #        mkdir $directory or log_fatal $!;
    }

    foreach my $subdir (qw(output scripts)) {
        mkdir $self->workdir . "/$subdir" or log_fatal 'Could not create directory ' . $self->workdir . "/$subdir : " . $!;
    }

    # catching Ctrl-C interruption
    local $SIG{INT} =
        sub {
        log_info "Caught Ctrl-C, all jobs will be interrupted";
        $self->_delete_jobs_and_exit();
        };

    $self->_create_job_scripts();
    $self->_run_job_scripts();

    STDOUT->autoflush(1);
    STDERR->autoflush(1);

    $self->_wait_for_jobs();

    $self->_print_execution_time();

    log_info "All jobs finished.";

    if ( $self->cleanup ) {
        log_info "Deleting the directory with temporary files " . $self->workdir;
        rmtree $self->workdir or log_fatal $!;
    }
    return;
}

sub _redirect_output {
    my ( $outdir, $docnumber, $jobindex ) = @_;
    my $job = sprintf( 'job%03d', $jobindex + 0 );
    my $doc = $docnumber ? sprintf( "doc%07d", $docnumber ) : 'loading';
    my $stem = "$outdir/$job-$doc";
    open my $OUTPUT, '>', "$stem.stdout" or log_fatal $!;    # where will these messages go to, before redirection?
    open my $ERROR,  '>', "$stem.stderr" or log_fatal $!;
    STDOUT->fdopen( $OUTPUT, 'w' ) or log_fatal $!;
    STDERR->fdopen( $ERROR,  'w' ) or log_fatal $!;
    STDOUT->autoflush(1);

    # special file is touched if log_fatal is called
    Treex::Core::Log::add_hook(
        'FATAL',
        sub {
            eval { system qq(touch $stem.fatalerror) };      ## no critic (RequireCheckingReturnValueOfEval)
            }
    );
    return;
}

# not a method !
sub treex {

    # ref to array of arguments, or a string containing all arguments as on the command line
    my $arguments = shift;

    if ( ref($arguments) eq 'ARRAY' && scalar @$arguments > 0 ) {
        my $idx = first_index { $_ eq '--' } @$arguments;
        my %args = ( argv => $arguments );
        if ( $idx != -1 ) {
            $args{filenames} = [ splice @$arguments, $idx + 1 ];
            pop @$arguments;    # delete "--"
        }
        my $runner = Treex::Core::Run->new_with_options( \%args );
        $runner->_execute();

    }

    elsif ( defined $arguments && ref($arguments) ne 'ARRAY' ) {
        treex( [ grep { defined $_ && $_ ne '' } split( /\s/, $arguments ) ] );
    }

    else {
        treex('--help');

        #log_fatal 'Unspecified arguments for running treex.';
    }
    return;
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
# The document reader is restarted, so it starts reading the first file again.
# To exit this "watching loop" either rm timestamp.file or press Ctrl^C.

BENEFITS:
* much faster development cycles (e.g. most time of en-cs translation is spent on loading)
* Now I have some non-deterministic problems with loading NER::Stanford
  - using --watch I get it loaded on all jobs once and then I don't have to reload it.

TODO:
* modules are just reloaded, no constructors are called yet


=for Pod::Coverage BUILD get_version

=encoding utf-8

=head1 NAME

Treex::Core::Run + treex - applying Treex blocks and/or scenarios on data

=head1 SYNOPSIS

In bash:

 > treex myscenario.scen -- data/*.treex
 > treex My::Block1 My::Block2 -- data/*.treex

In Perl:

 use Treex::Core::Run q(treex);
 treex([qw(myscenario.scen -- data/*.treex)]);
 treex([qw(My::Block1 My::Block2 -- data/*.treex)]);

=head1 DESCRIPTION

C<Treex::Core::Run> allows to apply a block, a scenario, or their mixture on a
set of data files. It is designed to be used primarily from bash command line,
using a thin front-end script called C<treex>. However, the same list of
arguments can be passed by an array reference to the function C<treex()>
imported from C<Treex::Core::Run>.

Note that this module supports distributed processing, simply by adding switch
C<-p>. Then there are two ways to process the data in a parallel fashion. By
default, SGE cluster\'s C<qsub> is expected to be available. If you have no
cluster but want to make the computation parallelized at least on a multicore
machine, add the C<--local> switch.

=head1 SUBROUTINES

=over 4

=item treex

create new runner and runs scenario given in parameters

=back

=head1 USAGE

__USAGE__

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
