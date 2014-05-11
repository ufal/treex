package Test::TreexTool;

use strict;
use warnings;
use Exporter;

BEGIN {
    use base qw(Exporter);

    our @ISA    = qw(Exporter);
    our @EXPORT = qw(test_tool router);
}

use Test::More;

use FindBin;
use Capture::Tiny qw(capture_merged tee_merged);
use Treex::Core::Scenario;
use Treex::Core::Config;
use Treex::Service::Router;
use File::Spec;
use File::Temp;
use Test::Files;

my $closed;

our $socket = "ipc://tool-testing-socket-$$";
$ENV{TREEX_SERVER_URL} = $socket;

is(Treex::Core::Config->treex_server_url, $socket, 'server url');

# init router
my $router = Treex::Service::Router->new(endpoint => $socket);
$router->listen;

sub router { $router }

sub test_tool {
    my ($tool_name, $scen) = @_;

    $ENV{USE_SERVICES} = 1;
    my $scenario;
    my $service_fh = File::Temp->new();
    my $service_file = $service_fh->filename;

    my $out = capture_merged {
        $scenario=undef;
        $scenario = Treex::Core::Scenario->new(
            scenario_string => $scen . "\nWrite::Treex to=$service_file\n"
        );
        $scenario->load_blocks;
        $scenario->run;
    };

    unlike($out, qr/Initializing with no service for/, 'service init ok')
      or BAIL_OUT('Service use failed');

    $ENV{USE_SERVICES} = 0;
    my $no_service_fh = File::Temp->new();
    my $no_service_file = $no_service_fh->filename;

    $out = capture_merged {
        $scenario=undef;
        $scenario = Treex::Core::Scenario->new(
            scenario_string => $scen . "\nWrite::Treex to=$no_service_file\n"
        );
        $scenario->load_blocks;
        $scenario->run;
    };

    like($out, qr/Initializing with no service for/, 'service init ok');

    compare_ok($no_service_file, $service_file,
               "Running scenario with service and without service for '$tool_name' yields same results");
}

1;
__END__

=head1 NAME

Test::TreexTool - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Test::TreexTool;
   blah blah blah

=head1 AUTHOR

Michal Sedlak E<lt>sedlak@ufal.mff.cuni.czE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
