package Treex::Block::W2A::EN::RehangZparToPdtStyle;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $conj ) = @_;
    
    # Skip all but coordinating conjunctions
    return if $conj->tag ne 'CC';
    
    my $last_member = $conj->parent;
    return if $last_member->is_root();
    my $coord_parent = $last_member->parent;
    
    $conj->set_parent($coord_parent);
    foreach my $member ($last_member->get_children({ordered=>1})){
        last if $member->ord > $conj->ord; 
        $member->set_parent($conj);
        if ($member->form ne ','){
            $member->set_is_member(1);
        }
    }
    $last_member->set_parent($conj);
    $last_member->set_is_member(1);
    return;
}
1;

__END__

=over

=item Treex::Block::W2A::EN::RehangZparToPdtStyle

Modifies the way of hanging coordinations
from the Zpar parser (with the default pre-trained model) style
to PDT a-level style. 

In ZPar the head of a coordination is the last member of coordination.
In PDT the head of a coordination is the conjunction.


C<W2A::EN::RehangConllToPdtStyle> must be used also to handle auxiliary verbs.

=back

=cut

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
