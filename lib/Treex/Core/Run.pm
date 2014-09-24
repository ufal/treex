package Treex::Core::Run;
use 5.008;
use forks;
use forks::shared;
use Moose;
use Treex::Core::Common;
use Treex::Core;
use Treex::Tool::Probe;
use MooseX::SemiAffordanceAccessor 0.09;
with 'MooseX::Getopt';

use Cwd;
use File::Path;
use File::Temp qw(tempdir);
use File::Which;
use List::MoreUtils qw(first_index);
use IO::Interactive;
use Time::HiRes;
use Readonly;
use POSIX;
use Exporter;
use Sys::Hostname;
use base 'Exporter';

use File::Glob 'bsd_glob';

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

has 'tokenize' => (
    traits        => ['Getopt'],
    cmd_aliases   => 't',
    is            => 'rw', isa => 'Bool',
    documentation => q{shortcut for adding "Read::Sentences W2A::Tokenize" at the beginning of the scenario (or W2A::XY::Tokenize if used with --lang=xy)},
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
        . 'Translates to "qsub -hard -l mem_free=$mem -l h_vmem=2*$mem -l act_mem_free=$mem". '
        . 'Use --mem=0 and --qsub to set your own SGE settings (e.g. if act_mem_free is not available).',
);

has 'name' => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa           => 'Str',
    default       => '',
    documentation => 'Prefix of submitted jobs. Requires -p. '
        . 'Translates to "qsub -N $name-jobname".',
);

has 'qsub' => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa           => 'Str',
    default       => '',
    documentation => 'Additional parameters passed to qsub. Requires -p. '
        . 'See --priority and --mem. You can use e.g. --qsub="-q *@p*,*@s*" to use just machines p* and s*.',
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

has 'dump_required_files' => (
    traits        => ['Getopt'],
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => 'Just dump (print to STDOUT) files required by the given scenario and exit.',
);

has 'survive' => (
    traits        => ['Getopt'],
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => 'Continue collecting jobs\' outputs even if some of them crashed (risky, use with care!).',
);

has 'cache' => (
    traits        => ['Getopt'],
    is            => 'rw',
    isa           => 'Str',
    default       => "",
    documentation => 'Use cache. Required memory is specified in format memcached,loading. Numbers are in GB.',
);

has 'server' => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa           => 'Str',
    default       => '',
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

#has '_fh_OUTPUT' => ( is => 'rw', isa => 'FileHandle');
#has '_fh_ERROR' => ( is => 'rw', isa => 'FileHandle');

our $_fh_OUTPUT;
our $_fh_ERROR;

our $OFFIC_STDOUT;
our $OFFIC_STDERR;

has '_number_of_docs' => ( is => 'rw', isa => 'Int',     default => 0 );
has '_max_started'    => ( is => 'rw', isa => 'Int',     default => 0 );
has '_max_loaded'     => ( is => 'rw', isa => 'Int',     default => 0 );
has '_max_finished'   => ( is => 'rw', isa => 'Int',     default => 0 );
has '_jobs_status'    => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has '_fatalerror_ts'  => ( is => 'rw', isa => 'Int',     default => 0 );
has '_fatalerror_job' => ( is => 'rw', isa => 'Str',     default => "" );
has '_fatalerror_doc' => ( is => 'rw', isa => 'Str',     default => "" );

has '_tmp_scenario_file' => ( is => 'rw', isa => 'Str', default => "" );
has '_tmp_input_dir'     => ( is => 'rw', isa => 'Str', default => "" );

my $consumer = undef;

Readonly my $sleep_min_time   => 5;
Readonly my $sleep_max_time   => 120;
Readonly my $sleep_multiplier => 1.1;
Readonly my $slice_size       => 0.2;

Readonly my $SERVER_HOST => hostname;
Readonly my $SERVER_PORT => int( 30000 + rand(32000) );

# For speculative execution, writers cannot use the final output filenames.
# They must use temporary files instead and only the first successful jobs
# will move its files to the final location.
# However, there is a bug in the renaming code (see Treex/Core/t/writers.t)
# so let's disable it. TODO: fix it properly.
# TODO: this constant does not turn on/off the speculative execution (but it should),
# just the renamig code.
our $SPECULATIVE_EXECUTION = 0;

our %sh_job_status : shared;
%sh_job_status = ( 'info_fatalerror' => 0 );

our $PORT : shared;
$PORT = $SERVER_PORT;

our $PORT_SET : shared;
$PORT_SET = 0;

our $fatal_hook_index = -1;

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

    open( $OFFIC_STDERR, ">&STDERR" );
    open( $OFFIC_STDOUT, ">&STDOUT" );

    if ( $self->jobindex ) {
        _redirect_output( $self->outdir, "loading", $self->jobindex );
    }

    # 'require' can't be changed to 'imply', since the number of jobs has a default value
    if ( ( $self->qsub || $self->jobindex ) && !$self->parallel ) {
        log_fatal "Options --qsub and --jobindex require --parallel";
    }
    return;
}

sub DESTROY {
    my $self = shift;

    if ( $self->jobindex ) {
        _redirect_output( $self->outdir, "terminating", $self->jobindex );
    }

    return;
}

sub _execute {
    my ($self) = @_;
    if ( $self->dump_scenario || $self->dump_required_files ) {

        # TODO: execute_locally does the same work as the following line in a more safe ways
        # (If someone wants to run treex -d My::Block my_scen.scen)
        my $scen_str = join ' ', @{ $self->extra_argv };
        $self->set_scenario( Treex::Core::Scenario->new( scenario_string => $scen_str, runner => $self ) );

        # TODO: Do it properly - perhaps, add a Scenario option to not load all the blocks.
        # We cannot create the real scenario instance without loading all the blocks
        # However, since r6307 some Scenario's functions were changed to methods, so we must create a dummy instance.

        #my @block_items = Treex::Core::Scenario::parse_scenario_string($scen_str);
        #my @block_items = $dummy_scenario->parse_scenario_string($scen_str);

        if ( $self->dump_scenario ) {
            print "# Full Scenario generated by 'treex --dump_scenario' on " . localtime() . "\n";
            print $self->scenario->construct_scenario_string( multiline => 1 ), "\n";
        }

        if ( $self->dump_required_files ) {
            print "# Required files generated by 'treex --dump_required_files' on " . localtime() . "\n";
            print join "\n", $self->scenario->get_required_files(), "\n";
        }
        exit;
    }

    if ( $self->dump_required_files ) {

        my $scen_str = join ' ', @{ $self->extra_argv };
        $self->set_scenario( Treex::Core::Scenario->new( scenario_string => $scen_str, runner => $self ) );

        print "# Required files generated by 'treex --dump_required_files' on " . localtime() . "\n";
        print join "\n", $self->scenario->get_required_files(), "\n";
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
    'tag'      => 'CdtTag',

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
            if ( $current ne $first ) {
                log_fatal 'All files (' . join( ',', @names ) . ') must have the same extension' . "\n" .
                    "    current = $current\n" .
                    "    first   = $first\n" .
                    "    curname = $name";
            }
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

    $self->_init_scenario();

    my $scenario = $self->scenario;

    if ( $self->jobindex ) {
        my $fn = $self->outdir . sprintf( "/../status/job%03d.loaded", $self->jobindex );
        open my $F, '>', $fn or log_fatal "Cannot open file $fn";
        close $F;
        my $reader = $scenario->document_reader;

        use Treex::Block::Read::ConsumerReader;
        my ( $hostname, $port ) = split( /:/, $self->server );
        $consumer = Treex::Block::Read::ConsumerReader->new(
            {
                host => $hostname,
                port => $port,
                from => '-'
            }
        );

        $consumer->set_jobindex( $self->jobindex );
        $consumer->set_jobs( $self->jobs );

        $consumer->started();

        $reader->set_jobs( $self->jobs );
        $reader->set_jobindex( $self->jobindex );

        local $SIG{'TERM'}    = \&term;
        local $SIG{'ABRT'}    = \&term;
        local $SIG{'SEGV'}    = \&term;
        local $SIG{'KILL'}    = \&term;
        local $SIG{'__DIE__'} = sub { term(); log_fatal( $_[0] ); die( $_[0] ); };

        mkdir $self->outdir;
        my $outdir = $self->_get_tmp_outdir( $self->outdir, $self->jobindex );
        _rm_dir($outdir);
        mkdir $outdir;
        $reader->set_outdir($outdir);

        if ($SPECULATIVE_EXECUTION) {
            for my $writer ( @{ $scenario->writers } ) {
                my $new_path = $self->_get_tmp_outdir( $writer->path, $self->jobindex );

                if ( $writer->path ) {
                    mkdir $writer->path;
                }
                _rm_dir($new_path);
                mkdir $new_path;

                $writer->set_path($new_path);

                if ( $writer->to && $writer->to eq "-" ) {
                    $writer->set_to("__FAKE_OUTPUT__");
                }
            }
        }

        $reader->set_consumer($consumer);

        # If we know the number of documents in advance, inform the cluster head now
        if ( $self->jobindex == 1 ) {
            $self->_set_number_of_docs( $reader->number_of_documents );

            #log_info "There will be $number_of_docs documents";
            $self->_write_total_doc_number( $self->_number_of_docs );
        }

        # TODO - nastavit logovani
    }

    my $runnin_started = time;
    $scenario->run();

    if ($consumer) {
        _redirect_output( $self->outdir, "terminating", $self->jobindex );
        $consumer->finished();
    }

    log_info "Running the scenario took " . ( time - $runnin_started ) . " seconds";

    if ( $self->jobindex && $self->jobindex == 1 && !$self->_number_of_docs ) {
        $self->_set_number_of_docs( $scenario->document_reader->number_of_documents );

        # This branch is executed only
        # when the reader does not know number_of_documents in advance.
        # TODO: Why is document_reader->doc_number is one higher than it should be?

        #log_info "There were $number_of_docs documents";
        $self->_write_total_doc_number( $self->_number_of_docs );
    }

    return;
}

END {

    #    log_warn("In function END");
    term();
}

sub term {
    use Carp;
    if ( $consumer && !$consumer->is_finished ) {

        #        log_warn("Calling consumer->fatalerror");
        $consumer->fatalerror();
    }

    return;
}

sub _get_tmp_outdir {
    my ( $self, $path, $jobindex ) = @_;

    if ($path) {
        $path =~ s/\/+$//;
    }

    my ( $hostname, $port ) = split( /:/, $self->server );
    if ( !$hostname ) {
        ( $hostname, $port ) = ( $SERVER_HOST, $PORT );
    }
    return construct_output_dir_name( $path, $jobindex, $hostname, $port );
}

sub construct_output_dir_name {
    my ( $path, $jobindex, $host, $port ) = @_;
    if ( !$path ) {
        $path = "";
    }

    my $new_path = $path . '__H.' . $host . '.P.' . $port . '__JOB__' . $jobindex;

    #log_warn("NEW: $new_path");

    return $new_path;
}

sub close_handles
{
    STDOUT->flush();
    STDOUT->sync();
    STDERR->flush();
    STDERR->sync();

    #    close(STDOUT);
    #    close(STDERR);

    STDOUT->fdopen( fileno($OFFIC_STDOUT), 'w' ) or die $!;
    STDERR->fdopen( fileno($OFFIC_STDERR), 'w' ) or die $!;

    if ($_fh_ERROR) {
        $_fh_ERROR->flush();
        $_fh_ERROR->sync();
        close($_fh_ERROR);
    }
    if ($_fh_OUTPUT) {
        $_fh_OUTPUT->flush();
        $_fh_OUTPUT->sync();
        close($_fh_OUTPUT);
    }

    STDOUT->flush();
    STDOUT->sync();
    STDERR->flush();
    STDERR->sync();

    return;
}

sub _init_scenario
{
    my $self = shift;

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

    if ( $self->tokenize ) {
        my $tokenizer = 'W2A::Tokenize';
        my $lang = $self->lang;
        if ($lang && $lang ne 'all'){
            my $module = 'Treex::Block::W2A::' . uc($lang) . '::Tokenize';
            if (eval "use $module;1"){
                $tokenizer = 'W2A::' . uc($lang) . '::Tokenize';
            }
        }
        $scen_str = "Read::Sentences $tokenizer $scen_str";
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

    my $loading_ended = time;
    log_info "Loading the scenario took " . ( $loading_ended - $loading_started ) . " seconds";

    return;
}

# This is called by distributed jobs (they don't have $self->workdir)
sub _write_total_doc_number {
    my ( $self, $number ) = @_;
    my $filename = $self->_file_total_doc_number();
    open my $F, '>', $filename or log_fatal $!;
    print $F $number;
    close $F;
    return;
}

# This is called by the main treex (it doesn't have $self->outdir)
sub _read_total_doc_number {
    my ($self) = @_;
    my $total_doc_number_file = $self->_file_total_doc_number();
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
        return 0;
    }
}

sub _file_total_doc_number
{
    my $self = shift;
    if ( $self->workdir ) {
        return $self->workdir . "/total_number_of_documents";
    }
    elsif ( $self->outdir ) {
        return $self->outdir . '/../total_number_of_documents';
    }
    else {
        log_fatal("Unknown setting.")
    }
}

sub _quote_argument {
    my $arg = shift;
    $arg =~ s/([\`\\\"\$])/\\$1/g;
    return '"' . $arg . '"';
}

sub _execute_jobs {
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

    foreach my $jobnumber ( 1 .. $self->jobs ) {
        $self->_create_job_script( sprintf( "%03d", $jobnumber ), $input );
        $self->_run_job_script($jobnumber);
    }

    log_info $self->jobs . ' jobs '
        . ( $self->local ? 'executed locally.' : 'submitted to the cluster.' )
        . ' Waiting for confirmation that they started...';

    return;
}

sub _create_job_script {
    my ( $self, $jobnumber, $input ) = @_;

    my $workdir     = $self->workdir;
    my $current_dir = Cwd::cwd;

    my $script_filename = "scripts/job$jobnumber.sh";
    open my $J, ">", "$workdir/$script_filename" or log_fatal $!;
    print $J "#!/bin/bash\n\n";
    my $started_file = ( $workdir =~ /^\// ? $workdir : "$current_dir/$workdir" )
        . "/status/job$jobnumber.started";

    print $J 'echo -e "$HOSTNAME\n"`date +"%s"` > ' . $started_file . ";\n";
    print $J "stat $started_file 1>&2 > /dev/null;\n";
    print $J "cd $current_dir\n\n";

    my $opts_and_scen = "";
    if ( $self->_tmp_scenario_file ) {
        my %extra = ();
        map { $extra{$_} = 1 } @{ $self->extra_argv };
        for my $arg ( @{ $self->ARGV } ) {
            if ( !$extra{$arg} ) {
                $opts_and_scen .= " " . _quote_argument($arg);
            }
        }
        $opts_and_scen .= " " . _quote_argument( $self->_tmp_scenario_file );
    }
    else {
        $opts_and_scen .= join ' ', map { _quote_argument($_) } @{ $self->ARGV };
    }

    if ( $self->filenames ) {
        $opts_and_scen .= ' -- ' . join ' ', map { _quote_argument($_) } @{ $self->filenames };
    }
    print $J $input . "treex --server=" . $SERVER_HOST . ":" . $SERVER_PORT . " --jobindex=$jobnumber --workdir=$workdir --outdir=$workdir/output $opts_and_scen"
        . " 2>> $workdir/status/job$jobnumber.started\n\n";
    print $J "date +'%s' > $workdir/status/job$jobnumber.finished\n";
    close $J;
    chmod 0777, "$workdir/$script_filename";

    return;
}

sub _run_job_script {
    my ( $self, $jobnumber ) = @_;

    my $workdir = $self->workdir;
    if ( substr( $workdir, 0, 1 ) ne '/' ) {
        $workdir = "./$workdir";
    }
    $self->{_jobs_finished}->{$jobnumber} = 0;

    my $script_filename = "scripts/job" . sprintf( "%03d", $jobnumber ) . ".sh";

    if ( $self->local ) {
        system "$workdir/$script_filename &";
    }
    else {
        my $mem       = $self->mem;
        my $qsub_opts = '-cwd -e error/ -S /bin/bash';
        if ($mem){
            my ($h_vmem, $unit) = ($mem =~ /(\d+)(.*)/);
            $h_vmem = (2*$h_vmem) . $unit;
            $qsub_opts .= " -hard -l mem_free=$mem -l h_vmem=$h_vmem -l act_mem_free=$mem";
        }
        if ($self->qsub){
            $qsub_opts .= ' ' . $self->qsub;
        }
        $qsub_opts .= ' -p ' . $self->priority;
        $qsub_opts .= ' -N ' . $self->name . '-job' . sprintf( "%03d", $jobnumber ) . '.sh ' if $self->name;

        open my $QSUB, "cd $workdir && qsub -v TREEX_PARALLEL=1 $qsub_opts $script_filename |" or log_fatal $!;    ## no critic (ProhibitTwoArgOpen)

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

    return;
}

=head2 _is_job_started

    _is_job_started($jobid)

Returns 1 if job C<$jobid> already started, false otherwise.

=cut

sub _is_job_started {
    my ( $self, $jobid ) = @_;
    return $self->_is_job_status( $jobid, "started" );
}

=head2 _is_job_loaded

    _is_job_loaded($jobid)

Returns 1 if job C<$jobid> is already loaded, false otherwise.

=cut

sub _is_job_loaded {
    my ( $self, $jobid ) = @_;
    return $self->_is_job_status( $jobid, "loaded" );
}

=head2 _is_job_finished

    _is_job_finished($jobid)

Returns 1 if job C<$jobid> is already finished, false otherwise.

=cut

sub _is_job_finished {
    my ( $self, $jobid ) = @_;
    return $self->_is_job_status( $jobid, "finished" );
}

=head2 _is_job_status

    _is_job_status($jobid, $status)

Returns 1 if job C<$jobid> has status C<$status>, false otherwise.

=cut

sub _is_job_status
{
    my ( $self, $jobid, $status ) = @_;

    Treex::Tool::Probe::begin("_is_job_status.call");

    #    log_info("JOB: $jobid\tSTATUS: $status");

    # use information from shared variable
    if ( $sh_job_status{ 'job_' . $jobid . '_' . $status } ) {
        $self->{_job_status}->{$jobid}->{$status} = $sh_job_status{ 'job_' . $jobid . '_' . $status };
    }

    # avoid redundant disc accesses
    if ( !$self->{_job_status}->{$jobid}->{$status} ) {
        Treex::Tool::Probe::begin("_is_job_status.disk");

        $self->{_job_status}->{$jobid}->{$status} = ( -f $self->_get_job_status_filename( $jobid, $status ) ? 1 : 0 );

        # check whether the job is broken
        if ($self->survive
            &&
            !$self->{_job_status}->{$jobid}->{$status} &&
            $status ne "fatalerror"
            )
        {
            $self->{_job_status}->{$jobid}->{$status} = $self->_is_job_status( $jobid, "fatalerror" );
        }

        Treex::Tool::Probe::end("_is_job_status.disk");
    }

    Treex::Tool::Probe::end("_is_job_status.call");

    return $self->{_job_status}->{$jobid}->{$status};
}

sub _get_job_status_filename
{
    my ( $self, $jobid, $status ) = @_;
    return $self->workdir . "/status/job" . sprintf( "%03d", $jobid ) . "." . $status;
}

sub _is_in_fatalerror
{
    my $self = shift;

    my $fatal_file = $self->workdir . "/status/fatalerror";

    my $timestamp = 0;
    if ( -f $fatal_file ) {
        $timestamp = ( stat($fatal_file) )[9];
    }

    # first use information stored in shared variable
    # sometimes fatal_file is not presented yet
    my ( $job, $doc ) = ( $sh_job_status{'info_fatal_job'}, $sh_job_status{'info_fatal_doc'} );
    if ( $job && $doc ) {
        $self->_set_fatalerror_job($job);
        $self->_set_fatalerror_doc($doc);
    }

    if ( $timestamp > $self->_fatalerror_ts ) {
        open( my $fh, "<", $fatal_file ) or log_fatal($!);
        while ( my $line = <$fh> ) {
            chomp $line;

            # TODO: quick fix - should not happen
            if ( !$line ) {
                next;
            }

            my ( $job, $doc ) = split( / /, $line );
            if ( $doc =~ /[0-9]+/ ) {
                my $error_file = $self->workdir . "/error/doc" . sprintf( "%07d", $doc ) . ".stderr";

                # sometimes error file is not stored yet
                # so keep older values
                if ( -f $error_file ) {
                    $self->_set_fatalerror_job($job);
                    $self->_set_fatalerror_doc($doc);
                }
            }
            else {
                $self->_set_fatalerror_job($job);
                $self->_set_fatalerror_doc($doc);
            }

            log_info( 'Fatal error found in job ' . $job . ( $doc =~ /[0-9]+/ ? ', document ' : ' ' ) . $doc );
            my $fatal_file = $self->_get_job_status_filename( $self->_fatalerror_job, "fatalerror" );
            qx(touch $fatal_file);
        }
        close($fh);
        $self->_set_fatalerror_ts($timestamp);
    }

    return ( $self->_fatalerror_job, $self->_fatalerror_doc );
}

sub _get_slice
{
    my ( $self, $total ) = @_;

    my $slice = int( $total * $slice_size );
    if ( $slice == 0 ) {
        $slice = 1;
    }

    return $slice;
}

# Prints error messages from the output of the current document processing.
sub _print_output_files {
    my ( $self, $doc_number ) = @_;

    if ( $sh_job_status{ "doc_" . $doc_number . "_skipped" } ) {
        return;
    }

    # To get utf8 encoding also when using qx (aka backticks):
    # my $command_output = qw($command);
    # we need to
    use open qw{ :std IO :encoding(UTF-8) };

    foreach my $stream (qw(stderr stdout)) {
        Treex::Tool::Probe::begin( "_print_output_files." . $stream );

        my $filename = $self->workdir . "/output/doc" . sprintf( "%07d", $doc_number ) . ".$stream";

        # log_info "Processing output file: " . $filename . " ( -f " . int(defined(-f $filename)) . ", -s " . int(-s $filename) . ")";

        # we have to wait until file is really creates the file
        if ( !-f $filename ) {
            my $TRIES = 7;
            my $try   = 0;
            while ( $try < $TRIES && -f $filename ) {
                Treex::Tool::Probe::begin( "_print_output_files." . $stream . ".sleep-first-file-check" );
                sleep(1);
            }

            #    if ( $doc_number == 1 && $stream eq "stdout" && $sh_job_status{"doc_" . $doc_number . "_finished"} ) {
            #        sleep(15);
            #    }
            Treex::Tool::Probe::end( "_print_output_files." . $stream . ".sleep-first-file-check" );
        }

        if ( !-f $filename ) {
            my $job_number = sprintf( "%03d", $self->_get_job_number_from_doc_number( $doc_number, "fatalerror" ) );
            my $message = "Document $doc_number finished without producing $filename. " .
                " It might be useful to inspect " . $self->workdir . "/status/job" . sprintf( "%03d", $job_number ) . ".loading.stderr";
            if ( $self->survive ) {
                log_warn("$message (fatal error ignored due to survival mode, be careful)");
                return;
            }
            else {
                log_fatal $message;
            }
        }

        # we have to wait until file is really written
        # However, stdout is quite often empty.
        my $wait_it = 0;
        `stat $filename`;
        if ( $stream eq 'stderr' && -s $filename == 0 ) {

            # Jan Stepanek advice
            `stat $filename`;
            Treex::Tool::Probe::begin( "_print_output_files." . $stream . ".sleep2" );

            # Definitely not the ideal solution but it helps at the moment (and it fails without it):
            sleep(3);
            Treex::Tool::Probe::end( "_print_output_files." . $stream . ".sleep2" );
        }

        #while ( -s $filename == 0 && $wait_it < 1 ) {
        #
        # print STDERR "Size: " . ( -s $filename) . "\n";
        #open my $FILE, '<:encoding(utf8)', $filename;
        #my $line = <$FILE>;
        #close $FILE;
        #log_info "File is still empty. " . $filename;
        #    Time::HiRes::usleep(300000);
        #    $wait_it++;
        #}

        if ( $stream eq "stdout" ) {

            # real cat is 12-times faster than cat implemented in perl
            # it is useful when large dataset is processed

            system("cat $filename");
        }
        else {
            my $job_number     = sprintf( "%03d", $self->_get_job_number_from_doc_number( $doc_number, "finished" ) );
            my $doc_number_str = sprintf( "%07d", $doc_number );
            my $success        = 0;
            my $try            = 0;
            my $TRIES          = 10;
            while ( $try < $TRIES && !$success ) {
                if ( $try > 0 ) {
                    sleep(4);

                    #log_info("$filename - $try");
                }
                open my $FILE, '<:encoding(utf8)', $filename or log_fatal $!;
                my $report = $self->forward_error_level;

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
                    print STDERR "doc${doc_number_str}_job${job_number}: $_";

                }
                close $FILE;

                #if ( ! $sh_job_status{"doc_" . $doc_number . "_finished"} ) {
                #    $try += $TRIES;
                #} else {
                $try++;

                #}
            }

            # test for the [success] indication on the last line of STDERR
            if ( !$success ) {
                my $msg = "Document $doc_number has not finished successfully (see $filename)";
                if ( $self->survive ) {
                    log_warn($msg);
                }
                else {
                    log_fatal($msg);
                }
            }
        }
        Treex::Tool::Probe::end( "_print_output_files." . $stream );

    }
    return;
}

sub _doc_submitted {
    my ( $self, $doc_number ) = @_;
    return ( $sh_job_status{ "doc_" . $doc_number . "_started" } );
}

sub _doc_started {
    my ( $self, $doc_number ) = @_;

    #log_warn("DOC: $doc_number; FIN: " . int(defined($sh_job_status{"doc_" . $doc_number . "_finished"})) . "; FATAL: " . int(defined($sh_job_status{"doc_" . $doc_number . "_fatalerror"})));
    #return ( $sh_job_status{"doc_" . $doc_number . "_finished"} || $sh_job_status{"doc_" . $doc_number . "_fatalerror"} );
    my $filename = $self->workdir . sprintf( '/output/doc%07d.stderr', $doc_number );

    #log_info("DOC Started: " . $filename);
    return -f $filename;
}

sub _wait_for_jobs {
    my ($self)              = @_;
    my $current_doc_number  = 1;
    my $current_doc_started = 0;
    my $total_doc_number    = $self->_number_of_docs;
    my $all_jobs_finished   = 0;
    my $done                = 0;
    my $jobs_finished       = 1;
    my $docs_submitted      = 1;

    my $sleep_time            = $sleep_min_time;
    my $last_status_msg       = "";
    my $last_status_skipped   = 0;
    my $last_fatalerror_count = 0;

    my $missing_docs = 0;

    log_info("\n");

    my $job_slice = $self->_get_slice( $self->jobs );
    $sh_job_status{'info_crashed_jobs'} = 0;

    my $document_slice = 0;
    my $check_errors   = 0;

    my $finished_sleep = 0;

    while ( !$done ) {

        # count already started jobs
        if (
            $self->{_max_started} != $self->jobs &&
            $self->_is_job_started( $self->{_max_started} + 1 )
            )
        {
            $self->{_max_started} += 1;
            $check_errors ||= int( $self->{_max_started} % $job_slice == 1 );
            $sleep_time = $self->_sleep_time_dec($sleep_time);
            next;
        }

        # count already laoded jobs
        if (
            $self->{_max_loaded} < $self->{_max_started} &&
            $self->{_max_loaded} != $self->jobs &&
            $self->_is_job_loaded( $self->{_max_loaded} + 1 )
            )
        {
            $self->{_max_loaded} += 1;
            $check_errors ||= int( $self->{_max_loaded} % $job_slice == 1 );
            $sleep_time = $self->_sleep_time_dec($sleep_time);
            next;
        }

        # count already finished jobs
        if (
            $self->{_max_finished} < $self->{_max_loaded} &&
            $self->{_max_finished} != $self->jobs &&
            $self->_is_job_finished( $self->{_max_finished} + 1 )
            )
        {
            $self->{_max_finished} += 1;
            $check_errors ||= int( $self->{_max_finished} % $job_slice == 1 );
            $all_jobs_finished = ( $self->{_max_finished} == $self->jobs );
            $sleep_time        = $self->_sleep_time_dec($sleep_time);
            next;
        }

        $total_doc_number ||= $self->_read_total_doc_number();
        $current_doc_started ||= $self->_doc_started($current_doc_number);

        while ( $self->_doc_submitted($docs_submitted) ) {
            $docs_submitted++;
        }

        # If a job starts processing another doc,
        # it means it has finished the current doc.
        my $current_doc_finished = $all_jobs_finished;
        $current_doc_finished ||= $self->_doc_started( $current_doc_number + 1 );

        if ( $current_doc_started && $current_doc_finished ) {
            $self->_print_output_files($current_doc_number);
            $current_doc_number++;
            $current_doc_started = 0;

            # decrease sleeping time if we are printing out documents
            $sleep_time = $self->_sleep_time_dec($sleep_time);

            $document_slice ||= $self->_get_slice($total_doc_number);
            $check_errors   ||= int( $current_doc_number % $document_slice == 1 );
            $missing_docs = 0;
            next;
        }
        else {

            my $act_status_msg = sprintf(
                "Jobs: %3d started, %3d loaded | Docs: %5d/%5d/%5d",
                $self->{_max_started},
                $self->{_max_loaded},
                $current_doc_number - 1,
                $docs_submitted - 1,
                $total_doc_number
            );

            if ( $act_status_msg eq $last_status_msg ) {
                $last_status_skipped++;
                if ( $last_status_skipped > 5 ) {
                    $last_status_skipped = 0;
                    $last_status_msg     = "";

                    # maybe there is an error
                    $check_errors = 1;
                }
            }

            if ( $last_status_msg ne $act_status_msg ) {
                log_info($act_status_msg);
            }
            $last_status_msg = $act_status_msg;

            #use Data::Dumper;
            #log_info(Data::Dumper->Dump([\%sh_job_status]));

            Treex::Tool::Probe::begin("_wait_for_jobs.sleep");
            sleep $sleep_time;
            Treex::Tool::Probe::end("_wait_for_jobs.sleep");

            # increase sleeping time if nothing happened
            $sleep_time *= $sleep_multiplier;
            if ( $sleep_time > $sleep_max_time ) {
                $sleep_time = $sleep_max_time / 2;

                # maybe there is an error
                $check_errors = 1;
            }
        }

        if ( $last_fatalerror_count != $sh_job_status{"info_fatalerror"} ) {
            $check_errors          = 1;
            $last_fatalerror_count = $sh_job_status{"info_fatalerror"};
        }

        if ( $current_doc_number == 0 ) {
            $check_errors = 1;
        }

        # check errors if necessary
        if ($check_errors) {
            $self->_check_job_errors( $self->{_max_finished} );
            $check_errors = 0;
        }

        # Both of the conditions below are necessary.
        # - $total_doc_number might be unknown (i.e. 0) before all_jobs_finished
        # - even if all_jobs_finished, we must wait for forwarding all output files
        # Note that if $current_doc_number == $total_doc_number,
        # the output of the last doc was not forwarded yet.
        $done = ( $all_jobs_finished && $current_doc_number > $total_doc_number );

        if ( $self->{_max_finished} == $self->jobs && $current_doc_number < $total_doc_number ) {
            $missing_docs++;
        }

        if ( $sh_job_status{'info_crashed_jobs'} == $self->jobs || $missing_docs > 5 ) {
            log_warn("All workers are dead.");
            $self->_delete_jobs();
            $self->_delete_tmp_dirs();
            $self->_exit_program();

        }

    }

    Treex::Tool::Probe::print_stats();
    return;
}

sub _sleep_time_dec
{
    my ( $self, $time ) = @_;
    $time /= $sleep_multiplier;
    if ( $time < $sleep_min_time ) {
        $time = $sleep_min_time;
    }

    return $time;
}

sub _print_execution_time {
    my ($self) = @_;

    my $time_total = 0;

    my %hosts = ();
    my @times = ();

    # read job log files
    for my $file_finished ( bsd_glob $self->workdir . "/status/job???.finished" ) {
        my $jobid = $file_finished;
        $jobid =~ s/.*job0*//;
        $jobid =~ s/\.finished//;

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

        push( @times, ( $time_finish - $time_start ) . "." . $jobid );
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
    log_info "Times: " . join( ", ", sort { $b <=> $a } @times );

    return;
}

sub _print_finish_status
{
    my $self = shift;

    my $fatal_file = $self->workdir . "/status/fatalerror";

    if ( !$self->survive || !-f $fatal_file ) {
        log_info "All jobs finished.";
        return;
    }

    my %broken_jobs = ();
    open( my $fh, "<", $fatal_file ) or log_fatal($!);
    while (<$fh>) {
        chomp;
        my @p = split( / /, $_ );
        $broken_jobs{ $p[0] } = 1;
    }
    close($fh);

    my @jobs = sort { $a <=> $b } keys %broken_jobs;

    if ( scalar @jobs == 0 ) {
        log_info "All jobs finished.";
    }
    else {
        log_info "Fatal errors occurred in " . ( scalar @jobs ) . " out of " . $self->jobs . " jobs.";
        log_info "These jobs are: " . join( " ", @jobs );
    }

    return;
}

# To get utf8 encoding also when using qx (aka backticks):
# my $command_output = qx($command);
# we need to
use open qw{ :std IO :encoding(UTF-8) };

sub _check_job_errors {
    my ( $self, $from_job_number ) = @_;

    Treex::Tool::Probe::begin("_check_job_errors");

    my $workdir = $self->workdir;

    my ( $fatal_job, $fatal_doc ) = $self->_is_in_fatalerror();
    if ($fatal_job) {
        my $error_file = $workdir . "/status/" . sprintf( "job%03d", $fatal_job ) . "." . $fatal_doc . ".stderr";
        if ( $fatal_doc =~ /[0-9]+/ ) {
            $error_file = $workdir . "/output/" . sprintf( "doc%07d", $fatal_doc ) . ".stderr";
            if ( !-d $error_file ) {
                $error_file = $workdir . "/error/" . sprintf( "doc%07d", $fatal_doc ) . ".stderr";
            }
        }
        my $command     = "grep -h -A 10 -B 25 FATAL $error_file";
        my $fatal_lines = qx($command);
        if (!$fatal_lines) {
            $command = "tail -n 35 $error_file";
            $fatal_lines = qx($command);
        }
        log_info "********************** $command  ******************";
        log_info "********************** FATAL ERRORS FOUND IN JOB $fatal_job ******************\n";
        log_info "$fatal_lines\n";
        log_info "********************** END OF JOB $fatal_job FATAL ERRORS LOG ****************\n";

        # create fatal error file for particular job
        my $fatal_file = $self->_get_job_status_filename( $fatal_job, "fatalerror" );
        qx($command >> $fatal_file);

        # mark job as in fatal error state
        $self->_is_job_status( $fatal_job, "fatalerror" );

        if ( !$self->survive ) {
            log_info "Fatal error(s) found in one or more jobs. All remaining jobs will be interrupted now.";
            $self->_delete_jobs();
            $self->_delete_tmp_dirs();
            $self->_exit_program();

        }
    }
    $self->_check_epilog_before_finish($from_job_number);

    Treex::Tool::Probe::end("_check_job_errors");

    return;
}

sub _check_epilog_before_finish {
    my ( $self, $from_job_number ) = @_;

    Treex::Tool::Probe::begin("_check_epilog_before_finish");
    my $workdir = $self->workdir;
    $from_job_number ||= 1;
    for my $job_num ( $from_job_number .. $self->jobs ) {
        my $job_str = sprintf( "job%03d", $job_num );
        if ( $self->name ) {
            $job_str = $self->name . "-" . $job_str;
        }
        next if $self->_is_job_finished($job_num);
        my $epilog_name = bsd_glob "$workdir/error/$job_str.sh.e*";
        if ($epilog_name) {
            qx(stat $epilog_name);
            my $epilog = qx(grep EPILOG $epilog_name);

            # However, now we must check -f again, because the file could be created meanwhile.
            if ($epilog) {
                log_info "********************** UNFINISHED JOB $job_str PRODUCED EPILOG: ******************";
                log_info "**** cat $epilog_name\n";
                system "cat $epilog_name";

                #TODO - FIX
                #                log_info "********************** LAST STDERR OF JOB $job_str: ******************";
                #                log_info "**** tail $workdir/output/job$job_str-doc*.stderr\n";
                #                system "tail $workdir/output/job$job_str-doc*.stderr";
                log_info "********************** END OF JOB $job_str ERRORS LOGS ****************\n";
                if ( $self->survive ) {
                    $sh_job_status{ 'job_' . $job_num . '_' . "fatalerror" } = 1;
                    log_warn("Fatal error ignored due to the --survive option, be careful.");
                    my $act_crashed = $sh_job_status{'info_crashed_jobs'};
                    $act_crashed++;
                    if ( $act_crashed <= $self->jobs ) {
                        $sh_job_status{'info_crashed_jobs'} = $act_crashed;
                    }

                    #return;
                }
                else {
                    log_info "Fatal error(s) found in one or more jobs. All remaining jobs will be interrupted now.";
                    $self->_delete_jobs();
                    $self->_delete_tmp_dirs();
                    $self->_exit_program();
                }
            }
        }
    }

    Treex::Tool::Probe::end("_check_epilog_before_finish");

    return;
}

sub _exit_program {
    my $self = shift;
    log_info 'You may want to inspect generated files in ' . $self->workdir . '/output/';
    exit(1);
}

sub _delete_jobs {
    my $self = shift;

    log_info "Deleting jobs: " . join( ', ', @{ $self->sge_job_numbers } );
    my %jobs = ();
    foreach my $job ( @{ $self->sge_job_numbers } ) {
        qx(qdel $job);
        $jobs{$job} = 1;
    }

    my $continue = 0;
    do {
        $continue = 0;

        my $id_string = `qstat | tail -n +3 | cut -f1 -d" " | tr "\n" ,`;
        my @ids = split( /,/, $id_string );
        for my $id (@ids) {
            if ( defined( $jobs{$id} ) ) {
                $continue = 1;

                # log_warn("Job - $id - is still running.");
                sleep 2;
                last;
            }
        }
    } while ($continue);

    return;
}

sub _delete_tmp_dirs {
    my $self = shift;

    qx(sync);

    for my $j ( 1 .. $self->jobs ) {

        my $outdir = $self->_get_tmp_outdir( $self->outdir, $j );

        #log_warn("DEL: $outdir");
        _rm_dir($outdir);

        my $workdir = $self->_get_tmp_outdir( $self->workdir . "/output", $j );

        #log_warn("DEL: $workdir");
        _rm_dir($workdir);

        for my $writer ( @{ $self->scenario->writers } ) {
            my $new_path = $self->_get_tmp_outdir( $writer->path, $j );

            #log_warn("DEL: $new_path");
            _rm_dir($new_path);
        }
    }

    if ( $self->_tmp_input_dir && $self->_tmp_input_dir =~ /STDIN/ ) {
        _rm_dir( $self->_tmp_input_dir );
    }

    return;

}

sub _rm_dir {
    my $dir = shift;
    rmtree $dir;
    while ( -d $dir ) {
        sleep 1;
        log_info("Sleep before next rm");
        rmtree $dir;
    }
    rmtree $dir;
    return;
}

sub _execute_on_cluster {
    my ($self) = @_;

    $self->_init_scenario();

    log_info( "Execution begin at " . POSIX::strftime( '%Y-%m-%d %H:%M:%S', localtime ) );

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
            @existing_dirs = bsd_glob "$directory_prefix*";    # separate var because of troubles with glob context
            }
            while (@existing_dirs);
        my $directory = tempdir "${directory_prefix}XXXXX" or log_fatal($!);
        $self->set_workdir($directory);
        log_info "Working directory $directory created";

        #        mkdir $directory or log_fatal $!;
    }

    foreach my $subdir (qw(output scripts status error)) {
        my $dir = $self->workdir . "/$subdir";
        mkdir $dir or log_fatal 'Could not create directory ' . $dir . " : " . $!;
        qx(stat $dir);
    }
    sleep(1);

    if ($self->scenario->document_reader->isa("Treex::Block::Read::BaseTextReader")
        &&
        $self->scenario->document_reader->lines_per_doc
        )
    {
        log_info("Input file splitting - BEGIN");

        # construct scenario
        my @scenario_lines = split( /\n/, $self->scenario->construct_scenario_string( multiline => 1 ) );

        # retrieve line with reader
        my $reader_name = ref( $self->scenario->document_reader );
        $reader_name =~ s/Treex::Block:://;

        # TODO: iterovat + a je nutne doplnit i vsechny nad tim
        my $reader_line_num = 0;
        my @preserved_lines = ();
        for my $line (@scenario_lines) {
            push( @preserved_lines, $line );
            if ( $line =~ /\Q$reader_name\E/ ) {
                last;
            }
            $reader_line_num++;
        }
        my $reader_line = $scenario_lines[$reader_line_num];

        # create directory for splitted files
        my $first_from = $self->scenario->document_reader->from->filenames->[0];
        my $hash = sprintf( "STDIN_%09d", rand(1e9) );
        if ( $first_from ne "-" && $first_from ne "/dev/stdin" ) {
            $hash = $self->scenario->document_reader->from->get_hash();
        }
        $self->_set_tmp_input_dir( "__INPUT__" . $hash );

        # split files if they does not exist
        if ( !-d $self->_tmp_input_dir ) {
            mkdir $self->_tmp_input_dir;

            # split files and convert them to streex format
            my $tmp_scenario = Treex::Core::Scenario->new(
                from_string =>
                    join( "\n", @preserved_lines ) . "\n" .
                    "Write::Treex storable=1 path=" . _quote_argument( $self->_tmp_input_dir ) . "\n"
            );
            $tmp_scenario->run();
        }
        else {
            log_info("Already splitted");
        }

        # construct new scenario
        my $new_reader_line    = "Read::Treex from='!" . $self->_tmp_input_dir . "\/*.streex'";
        my @new_scenario_lines = map {
            my $line = $_;
            $line =~ s/\Q$reader_line\E/$new_reader_line/;
            $line;
        } @scenario_lines;

        # save scenario into new file
        $self->_set_tmp_scenario_file( $self->_tmp_input_dir . "/scenario.scen" );
        open( my $fh, ">:encoding(utf-8)", $self->_tmp_scenario_file ) or log_fatal($!);
        print $fh join( "\n", @new_scenario_lines );
        close($fh);

        # construct new reader
        my $reader_scenario = Treex::Core::Scenario->new( from_string => $new_reader_line );
        $reader_scenario->load_blocks();
        $self->scenario->_set_document_reader( $reader_scenario->document_reader );

        log_info("Input file splitting - END");
    }

    # catching Ctrl-C interruption
    local $SIG{INT} =
        sub {
        log_info "Caught Ctrl-C, all jobs will be interrupted";
        $self->_delete_jobs();
        $self->_delete_tmp_dirs();
        $self->_exit_program();
        };

    # load models
    if ( $self->cache ) {

        require Treex::Tool::Memcached::Memcached;

        # determine required memory
        my ( $memcached_memory, $loading_memory ) = split( ",", $self->cache );
        if ( !$memcached_memory ) {
            $memcached_memory = 5;    # TODO: magic number
        }
        if ( !$loading_memory ) {
            $loading_memory = $memcached_memory;
        }

        # start memcached
        if ( !Treex::Tool::Memcached::Memcached::is_running() ) {
            Treex::Tool::Memcached::Memcached::start_memcached($memcached_memory);
            sleep 2;
        }

        # set cache for scenario
        $self->scenario->set_cache(
            Treex::Tool::Memcached::Memcached::get_connection("documents-cache")
        );

        # check missing models
        my @missing_files = ();
        for my $line ( $self->scenario->get_required_files() ) {
            chomp $line;
            my ( $package, $file ) = split( /\t/, $line );
            my $required_file = Treex::Core::Resource::require_file_from_share( $file, 'Memcached' );
            if (Treex::Tool::Memcached::Memcached::is_supported_package($package)
                &&
                !Treex::Tool::Memcached::Memcached::contains($required_file)
                )
            {
                my ($class, $constr_params) = Treex::Tool::Memcached::Memcached::get_class_from_filename($required_file);
                if ( !$class ) {
                    log_warn "Unknown model file for $file\n";
                    next;
                }

                push( @missing_files, [ $class, $constr_params, $required_file ] );
            }
        }

        # some files are missing => load
        if (@missing_files) {
            log_info("Models will be loaded - BEGIN");

            # create file with required files
            my $script = File::Temp->new( UNLINK => 0, TEMPLATE => 'loading-qsub-XXXX', SUFFIX => '.sh' );
            print $script "#!/bin/bash\n";
            print $script "perl -e 'use Treex::Tool::Memcached::Memcached;";
            for my $item (@missing_files) {
                my ( $class, $constr_params, $required_file ) = @$item;
                print $script "Treex::Tool::Memcached::Memcached::load_model(\"$class\", \"$constr_params\", \"$required_file\" );";
            }
            print $script ";'\n";
            close $script;

            Treex::Tool::Memcached::Memcached::execute_script( $script, $loading_memory, $script, 1 );
            log_info("Models will be loaded - END");
        }

    }

    $self->_set_number_of_docs( $self->scenario->document_reader->number_of_documents );
    $self->_write_total_doc_number( $self->_number_of_docs );

    my $server_thread = threads->create(
        sub {
            use Treex::Block::Read::ProducerReader;
            my $producer = Treex::Block::Read::ProducerReader->new(
                {
                    reader   => $self->scenario->document_reader,
                    host     => $SERVER_HOST,
                    port     => $SERVER_PORT,
                    from     => '-',
                    status   => \%Treex::Core::Run::sh_job_status,
                    workdir  => $self->workdir,
                    writers  => $self->scenario->writers,
                    jobs     => $self->jobs,
                    log_file => $self->workdir . "/processing_info.log",
                    survive  => $self->survive
                }
            );

            }
    );
    $server_thread->detach();
    sleep(2);

    $self->_execute_jobs();

    STDOUT->autoflush(1);
    STDERR->autoflush(1);

    $self->_wait_for_jobs();

    $self->_print_execution_time();

    $self->_print_finish_status();

    $server_thread->kill(9);

    # delete jobs
    $self->_delete_jobs();
    $self->_delete_tmp_dirs();

    if ( $self->cleanup ) {
        log_info "Deleting the directory with temporary files " . $self->workdir;
        rmtree $self->workdir or log_fatal $!;
    }

    log_info( "Execution finished at " . POSIX::strftime( '%Y-%m-%d %H:%M:%S', localtime ) );

    return;
}

sub _redirect_output {
    my ( $outdir, $docnumber, $jobindex ) = @_;
    my $job = sprintf( 'job%03d', $jobindex + 0 );
    my $stem = $outdir . "/../status/$job.$docnumber";
    if ( $docnumber =~ /[0-9]+/ ) {
        $stem = "$outdir/" . sprintf( "doc%07d", $docnumber );
    }

    close_handles();

    open my $OUTPUT, '>', "$stem.stdout" or log_fatal $!;    # where will these messages go to, before redirection?
    open my $ERROR,  '>', "$stem.stderr" or log_fatal $!;

    $OUTPUT->autoflush(1);
    $ERROR->autoflush(1);

    $_fh_OUTPUT = $OUTPUT;
    $_fh_ERROR  = $ERROR;

    STDOUT->fdopen( $OUTPUT, 'w' ) or log_fatal $!;
    STDERR->fdopen( $ERROR,  'w' ) or log_fatal $!;

    STDERR->autoflush(1);
    STDOUT->autoflush(1);

    # special file is touched if log_fatal is called
    my $common_file_fatalerror = $outdir . "/../status/fatalerror";
    my $job_file_fatalerror    = $outdir . "/../status/" . $job . ".fatalerror";
    Treex::Core::Log::del_hook( 'FATAL', $fatal_hook_index );
    $fatal_hook_index = Treex::Core::Log::add_hook(
        'FATAL',
        sub {
            eval {
                system qq(echo $jobindex $docnumber >> $common_file_fatalerror);
                system qq(touch $job_file_fatalerror);
            };    ## no critic (RequireCheckingReturnValueOfEval)
            }
    );
    return;
}

sub _get_job_number_from_doc_number {
    my ( $self, $doc_number, $status ) = @_;
    if ( !$status ) {
        $status = "finished";
    }
    return $sh_job_status{ 'doc_' . $doc_number . '_' . $status };
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

=head2 --watch option

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
