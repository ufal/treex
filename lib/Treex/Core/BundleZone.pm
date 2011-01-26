package Treex::Core::BundleZone;

use Moose;
use Treex::Moose;

extends 'Treex::Core::Zone';

has sentence => (is => 'rw');

1;
