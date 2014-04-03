package Treex::Block::T2T::CopyCorefFromAlignment;

use Moose;
use Treex::Core::Common;
use 5.010;    # operator //

use Treex::Tool::Align::Utils;

extends 'Treex::Core::Block';

has 'type' => (
    is          => 'ro',
    isa         => enum( [qw/gram text/] ),
    required    => 1,
    default     => 'text',
);

sub _get_coref_nodes {
    my ($self, $node) = @_;

    my $method = $node->meta->find_method_by_name(
            'get_coref_'.$self->type.'_nodes');
    my @nodes = $method->execute( $node );
    return @nodes;
}

sub _add_coref_nodes {
    my ($self, $node, @antec) = @_;

    my $method = $node->meta->find_method_by_name(
            'add_coref_'.$self->type.'_nodes');
    $method->execute( $node, @antec );
}

sub process_tnode {
    my ( $self, $tnode ) = @_;

    my @antecs = $self->_get_coref_nodes($tnode);
    # nothing to do if no antecedent
    return if (@antecs == 0);
    
    my $align_filter = {rel_types => ['monolingual']};
    my @aligned_anaphs = Treex::Tool::Align::Utils::aligned_transitively([$tnode], [$align_filter]);
    my @aligned_antecs = Treex::Tool::Align::Utils::aligned_transitively(\@antecs, [$align_filter]);

    foreach my $source ( @aligned_anaphs ) {
        if (!defined $source) {
            print STDERR Dumper(\@aligned_anaphs);
        }
        if ( @aligned_antecs == 0 ) {
            my $antec = $antecs[0];
            if ( $antec->functor =~ /APPS|CONJ/ ) {
                my @antec_children = $antec->children;
                push @aligned_antecs, $antec_children[0]->get_aligned_nodes_of_type('monolingual');
#                 print $aligned_antecs[0]->get_address . "\n";
            }
            else {
#             elsif ( defined $antec->is_generated ) {
                foreach my $prev_antec ( $antec->get_coref_chain ) {
                    my @aligned_nodes = $prev_antec->get_aligned_nodes_of_type('monolingual');
                    if ( @aligned_nodes != 0 ) {
                        push @aligned_antecs, @aligned_nodes;
#                         print $aligned_antecs[0]->get_address . "\n";
                        last;
                    }
                }
            }
#             else {
#                 print $source->get_address . "\n";
#             }
        }

        # remove a possibly inserted 'anaph' itself from the list of its antecedents
        @aligned_antecs = grep {$_ != $source} @aligned_antecs;
        $self->_add_coref_nodes( $source, @aligned_antecs );
    }
}

1;

=head1 NAME

Treex::Block::T2T::CopyCorefFromAlignment

=head1 DESCRIPTION

TODO

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
