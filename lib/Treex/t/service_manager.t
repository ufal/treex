#!/usr/bin/env perl
# Run this like so: `perl service_manager.t'
#   Michal Sedlak <sedlak@ufal.mff.cuni.cz>     2014/02/22 15:34:33

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;

BEGIN { use_ok (qw/Treex::Service::Manager/) }

my $sm = Treex::Service::Manager->new();

ok($sm->module_exists('addprefix'), 'Module AddPrefix exists');

my $s1 = $sm->get_service('addprefix', {prefix => 'text_'});
my $s2 = $sm->get_service('addprefix', {prefix => 'text_'});
my $s3 = $sm->get_service('addprefix', {prefix => 'other_text_'});

is($sm->service_count, 2, 'We have only two service instances');
is($s1, $s2, 'S1 and S2 are the same instances');
isnt($s1, $s3, 'S1 and S3 are not the same instances');
isnt($s2, $s3, 'S2 and S2 are not the same instances');

done_testing();
