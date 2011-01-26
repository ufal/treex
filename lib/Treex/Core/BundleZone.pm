package Treex::Core::DocZone;

use Moose;
use MooseX::FollowPBP;

extends 'Treex::Core::Zone';

has sentence => (is => 'rw');

1;
