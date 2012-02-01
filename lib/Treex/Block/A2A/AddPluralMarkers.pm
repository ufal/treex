package Treex::Block::A2A::AddPluralMarkers;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has as => (
  is  => 'ro',
  isa => enum( [qw(node suffix)] ),
  default => 'node',
);

sub process_anode {
    my ( $self, $anode ) = @_;   

    # Get plural nouns
    return if $anode->tag !~ /^NNP?S/;

    if ($self->as eq 'node'){
        $anode->create_child( { form => '#PLURAL' } )->shift_after_node($anode);
    } else{
        $anode->set_form($anode->form . '#PLURAL');
    }
    return;
}

1;

__END__

=head1 NAME

Treex::Block::A2A::AddPluralMarkers - add artificial tokens after plurals

=head1 DESCRIPTION

Special token "#PLURAL" is added after plural nouns.

=head1 PARAMETERS

=head2 as

C<node>   ... add the marker as a new token (node)
C<suffix> ... add the marker as a suffix to the form of the object

# Copyright 2012 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
