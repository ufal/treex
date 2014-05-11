#!/usr/bin/env perl
# Run this like so: `perl service_manager.t'
#   Michal Sedlak <sedlak@ufal.mff.cuni.cz>     2014/02/22 15:34:33

use FindBin;
use lib "$FindBin::Bin/lib";

use Test::More;

BEGIN { use_ok (qw/Treex::Service::Manager/) }

# basic functionality
{
    my $sm = Treex::Service::Manager->new();

    ok($sm->module_exists('addprefix'), 'Module AddPrefix exists');

    my $s1 = $sm->init_service('addprefix', {prefix => 'text_'});
    my $s2 = $sm->init_service('addprefix', {prefix => 'text_'});
    my $s3 = $sm->init_service('addprefix', {prefix => 'other_text_'});

    # Can't check this test with cache
    # is($sm->service_count, 2, 'We have only two service instances');
    is($s1, $s2, 'S1 and S2 are the same instances');
    isnt($s1, $s3, 'S1 and S3 are not the same instances');
    isnt($s2, $s3, 'S2 and S2 are not the same instances');
}

# test cache size
{
    my $sm = Treex::Service::Manager->new(cache_size => 2);

    # Cache size is two but there is a CG factor in play
    # so we create more services to make sure the cache GC hits
    my $s1   = $sm->init_service('addprefix', {prefix => 's1'});
    my $s2   = $sm->init_service('addprefix', {prefix => 's2'});
    my $s3   = $sm->init_service('addprefix', {prefix => 's3'});
    my $s4   = $sm->init_service('addprefix', {prefix => 's4'});
    my $s5   = $sm->init_service('addprefix', {prefix => 's5'});
    my $s1_1 = $sm->init_service('addprefix', {prefix => 's1'});

    isnt($s1, $s1_1, 'Cache is working');
}

done_testing();
