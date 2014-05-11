#!/usr/bin/env perl
# Run this like so: `perl service_client.t'
#   Michal Sedlak <sedlakmichal@gmail.com>     2014/02/22 16:56:55

use FindBin;
BEGIN {
    unshift @INC, "$FindBin::Bin/../lib";
    unshift @INC, "$FindBin::Bin/lib";
}

use TestTreexTool;
use Test::More;
BEGIN { use_ok (qw/Treex::Service::Client/) }

done_testing;
exit 0;

eval {
  my $client = Treex::Service::Client->new();

  ok($client->service_available('addprefix'), 'Service AddPrefix is available');

  my $res = $client->run_service('addprefix', {prefix => 'test_'}, [['a', 'b']]);
  is_deeply($res, [['test_a', 'test_b']], 'Result from client is ok');

  my $fixture_file = File::Spec->catfile($FindBin::Bin, 'fixtures', 'en_sample.txt');
  my $scenario_string = <<"SCEN";
Util::SetGlobal language=en
Read::Text from=$fixture_file
W2A::EN::Segment
W2A::Tokenize
W2W::AddPrefix prefix='lala_'
SCEN

  test_tool('AddPrefix', $scenario_string);
};

print STDERR "$@\n" if $@;
ok(!$@, "No errors during execution");

close_connection();

done_testing();
