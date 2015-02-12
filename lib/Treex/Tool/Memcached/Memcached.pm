package Treex::Tool::Memcached::Memcached;
use Treex::Core::Common;

use strict;
use warnings;

use Cache::Memcached;
use Data::Dumper;
use Storable;
use File::Basename;
use File::Temp;

Readonly my $FLAG_MODEL_LOADED => "__MODEL_LOADED__";

Readonly my $DEFAULT_MEMORY  => 10;
Readonly my $DEFAULT_THREADS => 4;

Readonly my $MEMCACHED_SHARE_PATH => 'installed_tools/memcached/memcached-1.4.13/memcached';

#
# Memcached wrapper initialization
#

# Test if Memcached server is installed and can be executed
my $MEMCACHED = `which memcached`;
if ( !$MEMCACHED ) {

    # no system-wide installation, try to find in treex shared directories
    $MEMCACHED = Treex::Core::Resource::require_file_from_share($MEMCACHED_SHARE_PATH);

    # test if it is can be executed, will fail upon first use if not
    # TODO: any ideas for a better/faster check ?
    # TODO: Shouldn't this fail right here (and not crash Treex if don't want to use cache)?
    $MEMCACHED = '' if ( system( $MEMCACHED . ' -h > /dev/null 2>&1' ) != 0 );
}

#  detect if we are running/want to run on cluster
my $CLUSTER = !$ENV{MEMCACHED_LOCAL} && system('qstat > /dev/null 2>&1') == 0 ? 1 : 0;

#
# Methods
#

sub start_memcached {

    my ($memory) = @_;
    $memory //= $DEFAULT_MEMORY;

    # die with an error message if we can't run memcached properly
    if ( !$MEMCACHED ) {
        log_fatal "The Memcached server must be installed manually (system-wide or "
            . "in the $MEMCACHED_SHARE_PATH Treex shared directory)";
    }

    my $server = get_memcached_hostname();

    if ( !$server ) {
        log_info "Memcached will be executed.\n";

        # create a script to run memcached
        my $memcached_memory = $memory * 1000;
        my $script = File::Temp->new( UNLINK => 0, TEMPLATE => 'memcached-qsub-XXXX', SUFFIX => '.sh' );
        print $script "#!bin/bash\n";
        print $script "$MEMCACHED -m $memcached_memory -I 64000000\n";
        print $script "rm $script\n";
        close $script;

        execute_script($script, $memory, "memcached");

        return 1;
    }
    else {
        log_info "Memcached is already executed at $server.\n";
        return 0;
    }
}

sub execute_script {
    my ($script, $memory, $name, $wait) = @_;

    # run on cluster
    if ($CLUSTER) {
        my $qsub_memory = "-hard -l mem_free=${memory}G -l act_mem_free=${memory}G -l h_vmem=${memory}G";

        # The stdout of qsub is something like: Your job 6041617 ("memcached") has been submitted
        # However, when using treex as Unix filter, this should not clutter stdout.
        # Let's redirect it to stderr using 1>&2.
        system("qsub -j y -cwd -S /bin/bash -N $name $qsub_memory $script 1>&2");
        sleep 2;
        if ( $wait ) {
            do {
                sleep 5;
                Treex::Core::Log::progress();
            } while (scalar grep {/\Q$name\E/} `qstat -r`);
        }
    }

    # run locally
    else {
        system("bash $script &") == 0 || log_fatal 'Cannot execute memcached locally';
        if ( $wait ) {
            do {
                sleep 5;
                progress();
            } while (scalar grep {/\Q$name\E/} `ps ax`);
        }
    }

    return;
}

sub stop_memcached {
    my $server = get_memcached_hostname();
    if ($server) {

        # kill memcached on the cluster
        if ($CLUSTER) {
            my @lines = grep {/memcached/} `qstat`;
            if ( !@lines ) {
                print STDERR "Memcached is not yours, you cannot stop it.";
                return 0;
            }
            $lines[0] =~ /^([0-9]+)/;
            `qdel -j $1`;
        }

        # kill memcached locally
        else {
            my $pid = first {/memcached($| )/} `ps ax`;
            $pid =~ s/^\s*([0-9]+).*$/$1/ if ($pid);
            if ( !$pid || system("kill $pid") != 0 ) {
                print STDERR "Could not stop memcached.";
                return 0;
            }
        }
        print STDERR "Memcached will be stopped.\n";
        return 1;
    }
    return 0;
}

sub get_memcached_hostname {

    # return machine name if running on the cluster
    if ($CLUSTER) {
        my @lines = grep {/memcached/} `qstat`;

        # Jobs where fifth column (state) contains "d" (deletion) should not be considered as running memcached servers
        @lines = grep {!/([^ ]+ +){4}d/} @lines;

        if (@lines) {
            my $server = "";
            while ( $server eq "" ) {
                chomp $lines[0];
                log_info $lines[0];
                $lines[0] =~ /all.q\@([^.]+)\..*/;    # TODO: this won't work when running in another network !!!
                $server = $1 // "";
                if ( !$server ) {
                    log_info "Waiting in queue...\n";
                    @lines = grep {/memcached/} `qstat`;
                    sleep 5;
                }
            }

            return $server;
        }
    }

    # return 'localhost' if running locally
    else {
        return 'localhost' if grep {/memcached($| )/} `ps ax`;
    }

    # memcached is not executed
    log_info "Memcached is not executed\n";
    return "";
}

sub load_model
{
    my ( $model_class, $constr_params_str, $file, $debug ) = @_;

    log_info "Loading $model_class from file $file";
    
    my $constr_params = {};
    if (defined $constr_params_str && $constr_params_str !~ /^\s*$/) {
        $constr_params = { split / /, $constr_params_str };
    }

    my $namespace = basename($file);

    my $memd = get_connection($namespace);

    if ( !$memd ) {
        return 0;
    }

    log_info "Loading file $file (Namespace: $namespace)";

    if ( !$memd->get($FLAG_MODEL_LOADED) ) {

        if ( -d $file ) {
            my @files = ( glob "$file/*" );
            foreach my $part (@files) {
                _load_model( $memd, $model_class, $constr_params, $part, $debug );
            }
        }
        elsif ( -f $file ) {
            _load_model( $memd, $model_class, $constr_params, $file, $debug )
        }
        else {
            log_fatal "File $file does not exist.";
        }

        $memd->set( $FLAG_MODEL_LOADED, 1 );
        log_info "Model loaded";
    }
    else {
        log_info "Model already loaded";
    }

    return 1;
}

sub _load_model
{
    my ( $memd, $model_class, $constr_params, $file, $debug ) = @_;

    eval "require $model_class" || croak("Cannot load $model_class.");
    my $model = $model_class->new($constr_params);
    $model->load($file);

    #    log_info "\tStoring to memcached";
    for my $label ( $model->get_input_labels() ) {
        my $stored_label = $label;

        if ( $debug ) {
            print STDERR "LABEL\t$label\n";
        }
        my $status = $memd->set( fix_key($label), $model->get_submodel($label) );
    }

    return;
}

sub contains
{
    my ( $file, @keys ) = @_;

    log_info( 'Checking: ' . $file );
    my $memd = get_connection( basename($file) );

    if ( !$memd ) {
        return 0;
    }
    if ( !@keys ) {
        my $loaded = $memd->get($FLAG_MODEL_LOADED);
        if ($loaded) {
            log_info "\tAlready loaded."
        }
        else {
            log_info "\tMissing.";
        }
        return $loaded;
    }
    else {
        foreach my $key (@keys) {
            my $loaded = $memd->get(fix_key($key));
            if ($loaded) {
                log_info "\t$key: loaded."
            }
            else {
                log_info "\t$key: missing.";
            }
        }
    }
    return;
}

sub get_connection
{
    my $namespace = shift;

    my $server = get_memcached_hostname();
    if ( !$server ) {
        return;
    }

    my $memd = Cache::Memcached->new(
        {
            'servers'            => ["$server:11211"],
            'debug'              => 0,
            'no_rehash'          => 1,
            'compress_threshold' => 10_000,
            'namespace'          => $namespace
        }
    );

    return $memd;
}

sub print_stats
{

    my $memd = get_connection();
    if ($memd) {
        print Data::Dumper->Dump( [ $memd->stats() ] );
    }

    return;
}

sub fix_key
{
    my $key = shift;
    $key =~ s/\s/__/g;
    return $key;
}

sub is_running {
    return get_memcached_hostname() ? 1 : 0;
}

sub get_class_from_filename {
    my $required_file = shift;

    if ( $required_file =~ /maxent/ ) {
        return ('Treex::Tool::TranslationModel::ML::Model', 'model_type maxent' );
    }
    elsif ( $required_file =~ /vw/ ) {
        return ('Treex::Tool::TranslationModel::ML::Model', 'model_type vw' );
    }
    elsif ( $required_file =~ /\.nb\./ ) {
        return ('Treex::Tool::TranslationModel::NaiveBayes::Model', '');
    }
    elsif ( $required_file =~ /\.static\./ ) {
        return ('Treex::Tool::TranslationModel::Static::Model', '');
    }

    return;
}

sub is_supported_package {
    my $package = shift;

    return $package =~ /(TrFAddVariants|TrLAddVariants|TrFRerank2)/;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Tool::Memcached::Memcached

=head1 DESCRIPTION

A wrapper to L<Cache::Memcached> to be used in Treex to store translation models.

The Memcached library must be installed (either system-wide, or in the treex shared directory)
for this to work.

The Memcached server may be executed either as a job on the cluster (by default, when SGE environment
is detected), or run as a process on the local computer (when there is no SGE environment detected,
or if $ENV{MEMCACHED_LOCAL} is set).

=head1 METHODS

=head2 get_memcached_hostname()

Returns the server hostname or empty string if memcached is not executed.
It also waits until memcached is executed if it was already scheduled.

=head2 start_memcached($memory = $DEFAULT_MEMORY)

Executes memcached server with requested memory (in gigabytes).
If the server is already executed it does nothing.

=head2 stop_memcached()

Executes memcached server with requested memory (in gigabytes).
If the server is already executed it does nothing.

=head2 load_model($model_class, $constr_params_str, $data_file)

Loads a translation model (i.e. all of its submodels) from the given file. The file name
serves as the namespace for Memcached. Model classes having a parametric constructor are
initialized with parameters extracted from a space-separated $constr_params_str.

=head2 contains($file, @keys)

Checks whether the given file is stored in Memcached, and, if @keys is non-empty,
if there are submodels loaded under the given keys.

=head2 get_connection()

Returns a direct connection using a L<Cache::Memcached> object.

=head2 print_stats()

=head1 TODO

Better handling of outputs, especially when running locally (delete them by default?).

Better Memcached detection (so that it's not needed to actually try to execute it), failing in
compilation if Memcached is not installed and not breaking Treex completely.

=head1 AUTHOR

Martin Majliš <majlis@ufal.mff.cuni.cz>

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
