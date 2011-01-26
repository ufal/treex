package Treex::Core::DocZone;

use Moose;
use MooseX::FollowPBP;

extends 'Treex::Core::Zone';

has text => (is => 'rw');

1;
