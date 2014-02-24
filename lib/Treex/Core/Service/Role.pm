package Treex::Core::Service::Role;

use Moose::Role;
use namespace::autoclean;

requires qw/manager name fingerprint initialize process/;

1;
