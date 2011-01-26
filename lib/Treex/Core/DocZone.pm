package Treex::Core::DocZone;

use Moose;
use Treex::Moose;

extends 'Treex::Core::Zone';

has text => (is => 'rw');

1;
