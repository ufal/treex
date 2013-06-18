package Treex::Block::A2N::EncodeBIO;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_zone {
    my ( $self, $zone ) = @_;
    
    # Initialize all BIO tags to O (other).
    foreach my $a_node ($zone->get_atree()->get_descendants()){
        $a_node->wild->{ne_bio} = 'O';
    }
    
    my $n_root = $zone->get_ntree();
    return if !$n_root;
    
    # TODO: in case of nested entities, only the outermost are printed, there should be a parameter
    my @n_nodes = $n_root->get_children();
    
    foreach my $n_node (@n_nodes){
        my ($first_a_node, @other_a_nodes) = sort {$a->ord <=> $b->ord} $n_node->get_anodes();
        
        # TODO warn
        next if !$first_a_node;
        
        $first_a_node->wild->{ne_bio} = 'B-' . $n_node->ne_type;
        foreach my $a_node (@other_a_nodes){
            $a_node->wild->{ne_bio} = 'I-' . $n_node->ne_type;
        }
    }
    
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::A2N::EncodeBIO - convert named entities to the BIO encoding

=head1 DESCRIPTION

Convert the named entities in n-trees into a wild attribut 'ne_bio' in each a-node.
BIO encoding means B<X-type>, where B<type> is the type of the named entity
and X is either B<B> (for the first word) or B<I> (for the other words).
Tokens which are not part of any named entity have B<O>.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
