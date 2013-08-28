package Treex::Block::HamleDT::EN::RehangModalVerbs;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
    my ( $self, $modal ) = @_;

    # Get the cases where $modal is a modal verb
    return if $modal->tag ne 'MD';
    
    # ... and $main is the main verb
    # TODO we should handle coordinations correctly
    #my ($main) = $modal->get_eparent( { or_topological => 1 } );
    my $main = $modal->get_parent();
    return if $main->is_root || $main->tag !~ /^V/;

    # Get $main's children that should be rehang to $modal to prevent non-projectivity
    my @to_rehang;
    if ($modal->precedes($main)){
        @to_rehang = grep { $_->precedes($modal)} $main->get_children();
    } else {
        @to_rehang = grep { $modal->precedes($_)} $main->get_children();
    }

    # Rehang $modal above $main
    $modal->set_parent( $main->get_parent() );
    $main->set_parent($modal);
    
    # Rehang @to_rehang below $modal
    foreach my $node (@to_rehang){
        $node->set_parent($modal);
    }
        
    return;
}

__END__

=head1 NAME

Treex::Block::HamleDT::EN::RehangModalVerbs - modal verbs should govern main verbs

=head1 DESCRIPTION

Change a-tree from
"I(parent=go) can(parent=go) go(parent=ROOT) there(parent=go)"
to
"I(parent=can) can(parent=ROOT) go(parent=can) there(parent=go)"

Let's say the modal verb is before the main (autosemantic) verb;
then words depending on the main verb and preceding the modal verb
will be rehang to the modal verb to prevent non-projectivities.  

# Copyright 2011 Martin Popel
# This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README.
