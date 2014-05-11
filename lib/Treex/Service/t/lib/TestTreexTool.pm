package TestTreexTool;

use strict;
use warnings;
use Exporter;

BEGIN {
    use base qw(Exporter);

    our @ISA    = qw(Exporter);
    our @EXPORT = qw(test_tool close_connection);
}

use Test::More;

use FindBin;
use Treex::Core::Scenario;
use File::Spec;
use File::Temp;
use Test::Files;

my $server_socket = File::Temp->new()->filename;
my $closed;

our $socket = "ipc://$server_socket";
$ENV{TREEX_SERVER_URL} = $socket;

my $treex_server_script = "$FindBin::Bin/test_server.pl";
my ($pid, $server);
eval {
    $pid = open($server, '-|', $treex_server_script, $socket)
      || die "Can't start server";
    print STDERR "server (pid: $pid) on: $socket\n";
};

die "$@\n" if $@;
ok(!$@, "No errors during server start");

sub test_tool {
    my ($tool_name, $scen) = @_;

    $ENV{USE_SERVICES} = 0;
    my $no_service_fh = File::Temp->new();
    my $no_service_file = $no_service_fh->filename;

    my $scenario = Treex::Core::Scenario->new(
        scenario_string => $scen . "\nWrite::Treex to=$no_service_file\n"
    );
    $scenario->load_blocks;
    $scenario->run;

    $ENV{USE_SERVICES} = 1;
    my $service_fh = File::Temp->new();
    my $service_file = $service_fh->filename;

    $scenario=undef;
    $scenario = Treex::Core::Scenario->new(
        scenario_string => $scen . "\nWrite::Treex to=$service_file\n"
    );
    $scenario->load_blocks;
    $scenario->run;
    $scenario=undef;

    compare_ok($no_service_file, $service_file,
               "Running scenario with service and without service for '$tool_name' yields same results");
}

sub close_connection {
    my $force = shift;

    return if $closed;

    kill($force ? 'KILL' : 'QUIT', $pid) if $pid;
    close $server if $server;

    print STDERR (!kill(0, $pid) ? "Server successfully killed\n" : "Server kill failed\n");
    $closed = 1;
}

END {
    close_connection(1);
}

1;
__END__

=head1 NAME

TestTreexTool - Perl extension for blah blah blah

=head1 SYNOPSIS

   use TestTreexTool;
   blah blah blah

=head1 AUTHOR

Michal Sedlak E<lt>sedlak@ufal.mff.cuni.czE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
