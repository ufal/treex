package Treex::Core::DocZone;

use Moose;
use MooseX::NonMoose;
use MooseX::FollowPBP;

extends 'Treex::Core::Zone';

has language => (is => 'rw');

has selector => (is => 'rw');

#has text => (is => 'rw');



#sub set_text {
#    my ($self, $text) = @_;
#    $self->value->{text} = $text;
#}


1;
