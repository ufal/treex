package Treex::Block::W2A::JA::RehangParticles;
use Moose;
use Treex::Core::Common;
use Encode;
extends 'Treex::Core::Block';

# While recursively depth-first-traversing the tree
# we sometimes rehang already processed parent node as a child node.
# But we don't want to process such nodes again.
my %is_processed;

sub process_atree {
    my ( $self, $a_root ) = @_;
    %is_processed = ();
    foreach my $child ( $a_root->get_children() ) {
        fix_subtree($child);
    }
    return 1;
}

sub fix_subtree {
    my ($a_node) = @_;

    if ( should_switch_with_parent($a_node) ) {
        switch_with_parent($a_node);
    }
    $is_processed{$a_node} = 1;
    
    # we want to process "と" and "や" particles before the others
    foreach my $child ( $a_node->get_children() ) {
        next if $is_processed{$child};
        next if ( $child->form ne "と" && $child->form ne "や" );
        fix_subtree($child);
    }

    # now we process the rest
    foreach my $child ( $a_node->get_children() ) {
        next if $is_processed{$child};
        fix_subtree($child);
    }

    return;
}

sub should_switch_with_parent {
    my ($a_node) = @_;
    my $tag = $a_node->tag;
    return 0 if $tag !~ /^Joshi/;
   
    # TODO: We may not want to rehang all particles (for example sentence ending particles)

    #Conjunctive particles should be taken care of independently
    return 0 if $tag =~ /Setsuzoku/;

    my $parent = $a_node->get_parent();
    return 0 if $parent->is_root();

    # All particles processed in following steps must stand after the word to which they are related
    return 0 if $a_node->precedes($parent);

    return 1;
}

sub switch_with_parent {
    my ($a_node) = @_;
    my $form = $a_node->form;
    my $parent = $a_node->get_parent();
    my $granpa = $parent->get_parent();
    $a_node->set_parent($granpa);
    $parent->set_parent($a_node);

    # "や" and "と" are similar to english "and" when listing things
    if ( $form eq 'や' || $form eq 'と' ) {
        my @children = $a_node->get_children(); 
        if ( @children == 1 ) {
            my $child = $children[0];
             
            # coordinated word should be located directly after particle
            my $following = $a_node->get_next_node();
            # check if word following particle is its parent and a noun
            my $parent = $a_node->get_parent();
            return if !defined $following;
            if ( $following == $parent  && $parent->tag =~ /^Meishi/ ) {
                my $granpa = $parent->get_parent();
                $a_node->set_parent($granpa);
                $parent->set_parent($a_node);
                foreach my $ch ( $a_node->get_children() ) { 
                    $ch->set_is_member(1); 
                }
            }
            # otherwise check if the following word is noun
            elsif ( $following->tag =~ /^Meishi/ ) {
                $child->set_is_member(1);
                $following->set_is_member(1);
            }
            
            # TODO: Rehang coordinated words, if they are siblings
            # also chceck, if current solution of coordinated words is correct
   
        }
    }
    return;
}

1;

__END__

=over

=item Treex::Block::W2A::JA::RehangParticles

Modifies the topology of trees parsed by JDEPP parser.
Blocks W2A::JA::RehangConjunctions and W2A::JA::RehangCopulas should be applied first. This block rehangs rest of the particles so they have position similar to prepositions.

=back

=cut

# Author: Dusan Varis 
