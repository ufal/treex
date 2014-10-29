package Treex::Core::Parallel::Node;

use 5.008;
use Moose;
use Treex::Core::Common;
use Treex::Core;
use MooseX::SemiAffordanceAccessor 0.09;

extends 'Treex::Core::Run';

use Treex::Block::Read::ConsumerReader;

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
use Sys::Hostname;
use base 'Exporter';

use File::Glob 'bsd_glob';


has '_number_of_docs' => ( is => 'rw', isa => 'Int',     default => 0 );

#has '_fh_OUTPUT' => ( is => 'rw', isa => 'FileHandle');
#has '_fh_ERROR' => ( is => 'rw', isa => 'FileHandle');

our $_fh_OUTPUT;
our $_fh_ERROR;

our $OFFIC_STDOUT;
our $OFFIC_STDERR;


has '_tmp_scenario_file' => ( is => 'rw', isa => 'Str', default => "" );
has '_tmp_input_dir'     => ( is => 'rw', isa => 'Str', default => "" );

my $consumer = undef;


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


# TODO this variable should not be needed (it is for the Head only), remove references from the code
our $PORT : shared;
$PORT = $SERVER_PORT;

our $fatal_hook_index = -1;


sub BUILD {

    # more complicated tests on consistency of options will be place here
    my ($self) = @_;

    open( $OFFIC_STDERR, ">&STDERR" );
    open( $OFFIC_STDOUT, ">&STDOUT" );

    _redirect_output( $self->outdir, "loading", $self->jobindex );

    return;
}

sub DESTROY {
    my $self = shift;

    _redirect_output( $self->outdir, "terminating", $self->jobindex );

    return;
}


sub _execute_scenario {
    my ($self) = @_;

    log_info "Parallelized execution. This process is one of the worker nodes, jobindex==" . $self->jobindex;

    $self->_init_scenario();
    my $scenario = $self->scenario;

    # Output redirections    
    my $fn = $self->outdir . sprintf( "/../status/job%03d.loaded", $self->jobindex );
    open my $F, '>', $fn or log_fatal "Cannot open file $fn";
    close $F;
    my $reader = $scenario->document_reader;

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
    
    # Main scenario execution
    my $runnin_started = time;
    $scenario->run();
    
    log_info "Running the scenario took " . ( time - $runnin_started ) . " seconds";
    
    
    if ( $self->jobindex == 1 && !$self->_number_of_docs ) {
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

# TODO this one and some following subroutines are now duplicated in the Head code: 
# either unify it, or remove unneeded ifs (I would vote for the latter – OD)
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

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Core::Parallel::Node - treex parallel processing worker node

=head1 DESCRIPTION

A derived class of L<Treex::Core::Run> that adds parallel processing capabilities
and is intended to run as a worker node that is governed by a L<Treex::Core::Parallel::Head>
instance.

=head1 SEE ALSO

L<Treex::Core::Run>

L<Treex::Core::Parallel::Head>

=head1 AUTHORS

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

Martin Majliš

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
