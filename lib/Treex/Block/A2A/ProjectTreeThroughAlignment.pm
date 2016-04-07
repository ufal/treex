package Treex::Block::A2A::ProjectTreeThroughAlignment;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has '+language'   => ( required => 1 );
has 'to_language' => ( is       => 'rw', isa => 'Str', required => 1 );
has 'to_selector' => ( is       => 'rw', isa => 'Str', required => 1 );

sub process_bundle {
    my ( $self, $bundle ) = @_;

    my $source_root = $bundle->get_zone( $self->language,    $self->selector )->get_atree;
    my $target_root = $bundle->get_zone( $self->to_language, $self->to_selector )->get_atree;

    foreach my $node ( $target_root->get_descendants ) {
        $node->set_parent($target_root);
    }
    foreach my $node ( $target_root->get_descendants ) {
        my $prev_node = $node->get_prev_node();
        $node->set_parent($prev_node) if $prev_node;
    }

    my %linked_to;
    my @counterparts;

    # sort counterparts for each node from 'int' through 'gdfa' to 'right'
    foreach my $node ( $source_root->get_descendants( { ordered => 1 } ) ) {
        my ( $nodes, $types ) = $node->get_directed_aligned_nodes();
		my $iterator = List::MoreUtils::each_arrayref($nodes, $types);
		while (my ($n, $t) = $iterator->() ) {
			if ( $t =~ /int/ ) {
				push @{ $counterparts[ $node->ord ] }, $n;
                $linked_to{ $n } = $node;
            }
		}
    }
    foreach my $node ( $source_root->get_descendants( { ordered => 1 } ) ) {
        my ( $nodes, $types ) = $node->get_directed_aligned_nodes();
		my $iterator = List::MoreUtils::each_arrayref($nodes, $types);
        while (my ($n, $t) = $iterator->() ) {
            if ( $t =~ /gdfa/ && $t !~ /int/ ) {
                push @{ $counterparts[ $node->ord ] }, $n;
                $linked_to{ $n } = $node;
            }
        }
    }
    foreach my $node ( $source_root->get_descendants( { ordered => 1 } ) ) {
        my ( $nodes, $types ) = $node->get_directed_aligned_nodes();
		my $iterator = List::MoreUtils::each_arrayref($nodes, $types);
        while (my ($n, $t) = $iterator->() ) {
            if ( $t =~ /right/ && $t !~ /gdfa/ ) {
                push @{ $counterparts[ $node->ord ] }, $n;
                $linked_to{ $n } = $node;
            }
        }
    }
	# TODO: Can this block be used with alignment created by 'Align::ReverseAlignment'?
	foreach my $node ( $source_root->get_descendants( { ordered => 1 } ) ) {
        my ( $nodes, $types ) = $node->get_directed_aligned_nodes();
        my $iterator = List::MoreUtils::each_arrayref($nodes, $types);
        while (my ($n, $t) = $iterator->() ) {
            if ( $t =~ /reverse_alignment/ && $t !~ /right/ ) {
                push @{ $counterparts[ $node->ord ] }, $n;
                $linked_to{ $n } = $node;
            }
        }
    }

    project_subtree( $bundle, $source_root, $target_root, \@counterparts );
}

sub project_subtree {
    my ( $bundle, $source_root, $target_root, $counterparts ) = @_;
    foreach my $source_node ( $source_root->get_children( { ordered => 1 } ) ) {
        my @other_target_nodes = @{ $$counterparts[ $source_node->ord ] } if $$counterparts[ $source_node->ord ];
        my $main_target_node = shift @other_target_nodes if @other_target_nodes;

        if ($main_target_node) {
            $main_target_node->set_parent($target_root);
            foreach my $target_node (@other_target_nodes) {
                next if $target_node eq $main_target_node;
                $target_node->set_parent($main_target_node);
                $target_node->set_attr( 'conll_deprel', 'new_node' );
            }
            project_subtree( $bundle, $source_node, $main_target_node, $counterparts );
        }
        else {
            project_subtree( $bundle, $source_node, $target_root, $counterparts );
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::ProjectTreeThroughAlignment

=head1 DESCRIPTION

Project an analytical tree from one zone to an other using alignment links.
Target trees must exist before an the alignment links must lead from the source to target
and must be typed as from GIZA++ ('int', 'int.gdfa', 'left.gdfa' etc.) 

=head1 AUTHOR

David Mareček <marecek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
