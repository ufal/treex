package Treex::Block::A2A::Retokenize;
use Moose;
use Treex::Core::Common;
use utf8;
use Treex::Block::W2A::Tokenize;
extends 'Treex::Core::Block';

has fix_alignment => ( is => 'rw', isa => 'Bool', default => 0 );

has tokenizer => ( is => 'rw', default => undef );

sub process_start {
    my ($self) = @_;

    $self->set_tokenizer(Treex::Block::W2A::Tokenize->new());

    return ;
}

sub process_anode {
    my ($self, $anode) = @_;

    return if $anode->isa('Treex::Core::Node::Deleted');
    
    my @tokens = split( /\s/,
        $self->tokenizer->tokenize_sentence($anode->form)
    );

    if ( @tokens > 1 ) {
        # we have to split $anode into new nodes
        # (otherwise simply return)
        
        my $aroot = $anode->get_root();
        my ($aligned_nodes_rf, $aligned_types_rf) = $anode->get_aligned_nodes();
    
        my $new_node;
        my @unaligned_nodes;
        foreach my $token (@tokens) {
            
            # create new node
            $new_node = $aroot->create_child(
                form           => $token,
                no_space_after => 1,
            );
            $new_node->shift_before_node($anode);
            
            # handle alignment links
            if ( $self->fix_alignment ) {
                
                # find first aligned node with identical form
                my $found_i;
                foreach my $i (0 .. $#$aligned_nodes_rf ) {
                    if ( $aligned_nodes_rf->[$i]->form eq $new_node->form ) {
                        $found_i = $i;
                        last;
                    }
                }
                
                if ( defined $found_i ) {
                    # 1:1 alignment of new node and found node
                    $new_node->add_aligned_node(
                        $aligned_nodes_rf->[$found_i],
                        $aligned_types_rf->[$found_i]
                    );
                    splice(@$aligned_nodes_rf, $found_i, 1);
                    splice(@$aligned_types_rf, $found_i, 1);
                } else {
                    # unaligned for now
                    push @unaligned_nodes, $new_node;
                }
                
            } else {
                # simply always copy all alignment links
                foreach my $i (0 .. $#$aligned_nodes_rf ) {
                    $new_node->add_aligned_node(
                        $aligned_nodes_rf->[$i], $aligned_types_rf->[$i]
                    );
                }
            }

        }

        # last node inherits no_space_after from orig node
        $new_node->set_no_space_after($anode->no_space_after);
        
        if ( $self->fix_alignment && @unaligned_nodes > 0 ) {
            # there are some unaligned nodes left:
            # align them to nodes remaining from the aligned nodes of anode
            foreach my $new_node (@unaligned_nodes) {
                foreach my $i (0 .. $#$aligned_nodes_rf ) {
                    $new_node->add_aligned_node(
                        $aligned_nodes_rf->[$i], $aligned_types_rf->[$i]
                    );
                }
            }
        }

        $anode->remove();
    }
    
    return ;
}

1;

=head1 NAME 

Treex::Block::A2A::Retokenize -- fix wrong tokenization

Bonus: can also try to fix alignment for the retokenized nodes.

=head1 DESCRIPTION

=head1 PARAMETERS

=over

=item fix_alignment
If there is alignment from the retokenized node to several other nodes,
try to distribute the alignment links over the new nodes based on simple heuristics.
Default is C<0> -- copy all alignment links to all newly created nodes.

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

