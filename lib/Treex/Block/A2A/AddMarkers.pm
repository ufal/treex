package Treex::Block::A2A::AddMarkers;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has as => (
  is  => 'ro',
  isa => enum( [qw(node suffix)] ),
  default => 'node',
);

my %TOKEN_FOR_AFUN = (
    Sb  => '#SUBJECT',
    Obj => '#OBJECT',
);

sub process_anode {
    my ( $self, $anode ) = @_;
    my $token = $TOKEN_FOR_AFUN{ $anode->afun } or return;
    if ($self->as eq 'node'){
        $anode->create_child( { form => $token } )->shift_after_node($anode);
    } else{
        $anode->set_form($anode->form . $token);
    }
    return;
}

__END__

=head1 NAME

Treex::Block::A2A::AddMarkers - add artificial tokens after subjects and objects

=head1 DESCRIPTION

Special token "#SUBJECT" is added after each subject. Similarly with "#OBJECT".

=head1 PARAMETERS

=head2 as

C<node>   ... add the marker as a new token (node)
C<suffix> ... add the marker as a suffix to the form of the subject/object

# Copyright 2012 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
