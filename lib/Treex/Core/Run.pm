package Treex::Core::Run;

use 5.008;

use Moose;
use Treex::Core::Common;
use Treex::Core;
use MooseX::SemiAffordanceAccessor 0.09;
with 'MooseX::Getopt';


# TODO some of these modules might not be needed, check this
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

has 'lang' => (
    traits        => ['Getopt'],
    cmd_aliases   => [ 'language', 'L' ],
    is            => 'rw', isa => 'Str',
    documentation => q{shortcut for adding "Util::SetGlobal language=xy" at the beginning of the scenario},
);

has 'selector' => (
    traits        => ['Getopt'],
    cmd_aliases   => 'S',
    is            => 'rw', isa => 'Str',
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


has 'watch' => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa           => 'Str',
    documentation => 're-run when the given file is changed TODO better doc',
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

has 'cache' => (
    traits        => ['Getopt'],
    is            => 'rw',
    isa           => 'Str',
    default       => "",
    documentation => 'Use cache. Required memory is specified in format memcached,loading. Numbers are in GB.',
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

#
# Parallel head execution options
# TODO move them to Treex::Core::Parallel::Head

has 'forward_error_level' => (
    traits        => ['Getopt'],
    cmd_aliases   => 'E',
    is            => 'rw', isa => 'ErrorLevel', default => 'WARN',
    documentation => q{messages with this level or higher will be forwarded from the distributed jobs to the main STDERR},
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

has 'queue' => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa           => 'Str',
    default       => '',
    documentation => 'SGE queue. Translates to "qsub -q $queue".',
);

has 'qsub' => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa           => 'Str',
    default       => '',
    documentation => 'Additional parameters passed to qsub. Requires -p. '
. 'See --priority and --mem. You can use e.g. --qsub="-q *@p*,*@s*" to use just machines p* and s*. '
. 'Or e.g. --qsub="-q *@!(twi*|pan*)" to skip twi* and pan* machines.',
);

has 'workdir' => (
    is            => 'rw',
    traits        => ['Getopt'],
    isa           => 'Str',
    default       => './{NNN}-cluster-run-{XXXXX}',
    documentation => 'working directory for temporary files in parallelized processing; ' .
        'one can create automatic directories by using patterns: ' .
        '{NNN} is replaced by an ordinal number with so many leading zeros to have length of the number of Ns, ' .
        '{XXXX} is replaced by a random string, whose length is the same as the number of Xs (min. 4). ' .
        'If not specified, directories such as 001-cluster-run, 002-cluster-run etc. are created',
);

has 'sge_job_numbers' => (
    is            => 'rw',
    traits        => ['NoGetopt'],
    documentation => 'list of numbers of jobs executed on sge',
    default       => sub { [] },
);

has 'survive' => (
    traits        => ['Getopt'],
    is            => 'rw',
    isa           => 'Bool',
    default       => 0,
    documentation => 'Continue collecting jobs\' outputs even if some of them crashed (risky, use with care!).',
);


#
# Parallel node/worker execution options
# TODO move them to Treex::Core::Parallel::Node

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

has 'server' => (
    traits        => ['Getopt'],
    is            => 'ro',
    isa           => 'Str',
    default       => '',
    documentation => 'Not to be used manually. Used to point parallel jobs to the head.',
);

#
#
#

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

    return;
}


sub _execute {
    my ($self) = @_;

    if ( $self->dump_scenario || $self->dump_required_files ) {

        # If someone wants to run treex -d My::Block my_scen.scen
        my $scen_str = $self->_construct_scenario_string_with_quoted_whitespace();
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

        $self->_execute_scenario();

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

# This is where the main work is done. It is overridden in parallel execution.
sub _execute_scenario {
    my ($self) = @_;

    log_info "Local (single-process) execution.";

    $self->_init_scenario();

    my $scenario = $self->scenario;

    my $runnin_started = time;
    $scenario->run();

    log_info "Running the scenario took " . ( time - $runnin_started ) . " seconds";

    return;
}

# Parameters can contain whitespaces that should be preserved
sub _construct_scenario_string_with_quoted_whitespace {
    my ($self) = @_;
    my @arguments;
    foreach my $arg ( @{ $self->extra_argv } ) {
        if ( $arg =~ /([^=\s]+)=(.*\s.*)$/ ) {
            my ( $name, $value ) = ( $1, $2 );
            $value =~ s/'/\\'/g;
            push @arguments, qq($name='$value');
        }
        else {
            push @arguments, $arg;
        }
    }
    return join ' ', @arguments;
}

sub _init_scenario {
    my ($self) = @_;

    my $scen_str = $self->_construct_scenario_string_with_quoted_whitespace();

    # some command line options are just shortcuts for blocks; the blocks are added to the scenario now
    if ( $self->filenames ) {
        my $reader = $self->_get_reader_name_for( @{ $self->filenames } );
        log_info "Block $reader added to the beginning of the scenario.";
        $scen_str = "$reader from=" . join( ',', @{ $self->filenames } ) . " $scen_str";
    }

    if ( $self->save ) {
        log_info "Block Write::Treex added to the end of the scenario.";
        $scen_str .= ' Write::Treex';
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


# A factory subroutine, creating the right Treex object for the job.
# (local single-process: Treex::Core::Run, parallel processing head: Treex::Parallel::Head,
# parallel processing worker node: Treex::Parallel::Node)
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
        my $runner;

        if (any { $_ =~ /^--jobindex/ } @$arguments){
            require Treex::Core::Parallel::Node;
            $runner = Treex::Core::Parallel::Node->new_with_options( \%args );
        }
        elsif (any { $_ =~ /^(--parallel|-p|-pj\d+)$/ } @$arguments){
            require Treex::Core::Parallel::Head;
            $runner = Treex::Core::Parallel::Head->new_with_options( \%args );
        }
        else {
            $runner = Treex::Core::Run->new_with_options( \%args );
        }
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

Note that this module supports distributed processing (Linux-only!), simply by
adding the switch C<-p>. The C<treex> method then creates a
C<Treex::Core::Parallel::Head> object, which extends C<Treex::Core::Run>
by providing parallel processing functionality.

Then there are two ways to process the data in a parallel fashion. By
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

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Martin Majliš

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
