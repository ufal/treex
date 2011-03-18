#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

BEGIN { use_ok('Treex::Core::Service') }

# ----- a dummy service declaration
package Treex::Service::AddPrefix;
use Moose;
extends 'Treex::Core::Service';
has prefix => ( is => 'ro' );

sub process {
    my ( $self, $arg_ref ) = @_;
    return { output => $self->prefix . $arg_ref->{input} };
}

#----- end of the dummy service declaration

package main;

my $service1 = Treex::Service::AddPrefix->instance( { prefix => 'un' } );
my $service2 = Treex::Service::AddPrefix->instance( { prefix => 'un' } );
my $service3 = Treex::Service::AddPrefix->instance( { prefix => 'non' } );

ok( $service1 eq $service2, 'the same service object returned for the same service arguments (singleton-like behavior)' );
ok( $service1 ne $service3, 'different service objects returned for different service arguments' );

cmp_ok( $service1->process( { input => 'known' } )->{output}, 'eq', 'unknown', 'service process called correctly' );

done_testing();

