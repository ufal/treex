package Treex::Tool::Memcached::Memcached;
use Treex::Core::Common;

use strict;
use warnings;

use Cache::Memcached;
use Data::Dumper;
use File::Basename;

use TranslationModel::MaxEnt::Model;
use TranslationModel::NaiveBayes::Model;

my $FLAG_MODEL_LOADED="__MODEL_LOADED__";

my $MEMCACHED_DIR = $ENV{TMT_ROOT} . "/share/installed_tools/memcached/memcached-1.4.1";
my $DEFAULT_MEMORY = 10;

=head2 start_memcached(memory = $DEFAULT_MEMORY)

Executes memcached server with requested memory (in gigabytes). 
If the server is already executed it does nothing. 

=cut

sub start_memcached {
    my ($memory) = @_;
    if ( ! defined($memory) ) {
        $memory = $DEFAULT_MEMORY;
    }

    my $memcached_memory = $memory * 1000;

    my $server = get_memcached_hostname();
    if ( ! $server ) {
        log_info "Memached will be executed.\n";
        system("qsubmit --jobname='memcached' --mem=${memory}G 'cd $MEMCACHED_DIR; ./memcached -m $memcached_memory");
        return 1;
    } else {
        log_info "Memached is already executed at $server.\n";
        return 0;
    }
}

=head2 start_memcached(memory = $DEFAULT_MEMORY)

Executes memcached server with requested memory (in gigabytes). 
If the server is already executed it does nothing. 

=cut

sub stop_memcached {
    my $server = get_memcached_hostname();
    if ( $server ) {
        my @lines = grep { /memcached/ } `qstat`;
        if ( ! @lines ) {
            print STDERR "Memcached is not yours, you cannot stop it.";
            return 0;
        }
        $lines[0] =~ /^([0-9]+)/;
        system("qdel -j $1");
        print STDERR "Memcached will be stopped.\n";
        return 1;
    }

    return 0;
}

=head2 get_memcached_hostname

Returns the server hostname or empty string if memcached is not executed.
It also waits until memcached is executed if was already scheduled.

=cut

sub get_memcached_hostname {
    my @lines = grep { /memcached/ } `qstat`;
    if (@lines) {
        my $server = "";
        while ( $server eq "" ) {
            $lines[0] =~ /all.q\@([^.]+)\..*/;
            $server = $1;
            if ( ! $server ) {
                log_info "Waiting in queue...\n";
                log_info $lines[0];
                sleep 5;
            }
        }

        return $server;
    }

    log_info "Memcached is not executed\n";

    # memcached is not executed
    return "";
}


sub load_model
{
    my ($model_class, $file) = @_;

    my $namespace = basename($file);

    my $memd = get_connection(basename($file));

    if ( ! $memd ) {
        return 0;
    }

    log_info "Loading file $$file";

    if ( ! $memd->get($FLAG_MODEL_LOADED) ) {

        my $model = $model_class->new();
        $model->load($file);

        log_info "Storing to memcached";

        for my $label ($model->get_input_labels() ) {
            my $status = $memd->set($label, $model->get_submodel($label));
        }

        $memd->set($FLAG_MODEL_LOADED, 1);
    } else {
        log_info "Already loaded";
    }

    return 1;
}

sub get_connection
{
    my $namespace = shift;

    my $server = get_memcached_hostname();
    if ( ! $server ) {
        return 0;
    }

    my $memd = Cache::Memcached->new({
        'servers' => [ "$server:11211" ],
        'debug' => 0,
        'compress_threshold' => 10_000,
        'namespace' => $namespace
    });

    return $memd;
}


sub print_stats
{

    my $memd = get_connection();
    if ( $memd ) {
        print Data::Dumper->Dump([$memd->stats()]);
    }

    return;
}

1;