package Treex::Block::Align::T::AlignCzechPersprons;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has to_language => ( isa => 'Str', is => 'ro', required => 1 );
has to_selector => ( isa => 'Str', is => 'ro', default  => '' );

sub process_ttree {
    my ( $self, $troot ) = @_;

    my $to_troot = $troot->get_bundle->get_tree( $self->to_language, 't', $self->to_selector );

    foreach my $t_node ( $troot->get_descendants ) {
        if ($t_node->is_generated) {
            my ($eparent) = $t_node->get_eparents;
            next if !$eparent;
            my ($en_tnodes, $types) = $eparent->get_directed_aligned_nodes;
            my ($en_eparent) = map {$$en_tnodes[$_]} grep {$$types[$_] =~ /int/} (0 .. $#$en_tnodes);
            next if !$en_eparent;
            foreach my $en_child ($en_eparent->get_echildren) {
                if ($en_child->functor eq $t_node->functor) {
                    $t_node->add_aligned_node( $en_child, 'rule-based');
                }
            }
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Align::T::AlignCzechPersprons

=head1 DESCRIPTION

This block aligns Czech generated #PersPron nodes.

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
