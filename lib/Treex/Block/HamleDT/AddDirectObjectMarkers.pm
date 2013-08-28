package Treex::Block::HamleDT::AddDirectObjectMarkers;
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
    
    # Get nouns serving as a direct object
    return if $anode->afun ne 'Obj';
    return if $anode->tag !~ /^NN/;
    
    
    # Skip conjuncts except for the last one
    return if $anode->is_member && any {$_->is_member} $anode->get_siblings({following_only=>1});


    if ($self->as eq 'node'){
        $anode->create_child( { form => '#OBJ', tag=>'ARTIFICIAL' } )->shift_after_node($anode);
    } else{
        $anode->set_form($anode->form . '#OBJ');
    }
    return;
}

1;
__END__

=head1 NAME

Treex::Block::HamleDT::AddDirectObjectMarkers - add artificial tokens after direct objects

=head1 DESCRIPTION

Special token "#OBJ" is added after direct objects.

=head1 PARAMETERS

=head2 as

C<node>   ... add the marker as a new token (node)
C<suffix> ... add the marker as a suffix to the form of the object

# Copyright 2012 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
