package Treex::Block::A2A::BackupTree;
use Moose;
use Treex::Core::Common;

# This is an alternative to A2A::CopyAtree and should supersede it.
# This block
# - interprets language as "source language" and needs specified to_language (similarly for selectors)
# - when no language si specified, it copies all languages found (to the new selector)
# - supports the new feature of multiple languages, e.g. A2A::BackupTree language=en,cs

extends 'Treex::Core::Block';

has 'to_language' => (
    is            => 'rw',
    isa           => 'Str',
    default       => '',
    documentation => 'what language should be filled in the target a-tree. Default (empty string) means the same language as the source a-tree.'
);
has 'to_selector' => ( is => 'rw', isa => 'Str', default => '' );

has 'flatten' => ( is => 'rw', isa => 'Bool', default => 0 );
has 'align'   => ( is => 'rw', isa => 'Bool', default => 0 );
has 'keep_alignment_links' => (is => 'rw', isa => 'Bool', default => 0);


sub process_atree {
    my ( $self, $src_root ) = @_;
    my $src_language = $src_root->language;
    my $src_selector = $src_root->selector;

    my $to_language = $self->to_language || $src_language;
    my $to_selector = $self->to_selector;
    
    # Create $to_root (root node of the target a-tree).
    # Note that create_atree() will log_fatal if such tree already exists.
    my $bundle  = $src_root->get_bundle();
    my $to_zone = $bundle->get_or_create_zone( $to_language, $to_selector );
    my $to_root = $to_zone->create_atree();

    # The main work is implemented in Treex::Core::Node::A
    $src_root->copy_atree($to_root);
    
    if ($self->align){
        my @src_nodes = $src_root->get_descendants( { ordered => 1 } );
        my @to_nodes  = $to_root->get_descendants( { ordered => 1 } );
        for my $i ( 0 .. $#to_nodes) {
            $to_nodes[$i]->add_aligned_node( $src_nodes[$i], 'copy' );
        }
    }
    
    if ( $self->flatten ) {
        foreach my $node ( $to_root->get_descendants ) {
            $node->set_parent($to_root);
            $node->set_is_member();
        }
    }
    
    if ( $self->keep_alignment_links) {
    	my @src_nodes = $src_root->get_descendants( { ordered => 1 } );
    	my @to_nodes  = $to_root->get_descendants( { ordered => 1 } );
    	# replicate incoming alignments (if any) in 'source_selector' to 'to_selector'
    	foreach my $sn (@src_nodes) {
    		my @referring_nodes = $sn->get_referencing_nodes('alignment');
    		if (@referring_nodes) {
    			foreach my $rn (@referring_nodes) {
    				my ($nodes_ref, $types_ref) = $rn->get_aligned_nodes_by_tree($src_language, $src_selector);
    				if ($nodes_ref) {
						my @aligning_nodes = @{$nodes_ref};
						my @types = @{$types_ref};
    					map{$rn->add_aligned_node($to_nodes[($aligning_nodes[$_]->ord)-1], $types[$_])}0..$#aligning_nodes;	
    				}
    				
    			}
    		}    		    		
    	}    	
    	# replicate outgoing alignments (if any) in 'source_selector' to 'to_selector'
    	foreach my $i (0..$#src_nodes) {
    		my ($nodes_ref, $types_ref) = $src_nodes[$i]->get_aligned_nodes();
    		if ($nodes_ref) {
				my @aligned_nodes = @{$nodes_ref};
				my @types = @{$types_ref};
    			map{$to_nodes[$i]->add_aligned_node($aligned_nodes[$_], $types[$_])}0..$#aligned_nodes;	
    		}
		}    	
    }
    
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::BackupTree - copy a-tree to another zone

=head1 SYNOPSIS

  # Copy the "current" zone to another selector (language is the same)
  A2A::BackupTree to_selector=my_backup
  
  # Copy English a-trees to Czech (target selector is empty if not specified)
  A2A::BackupTree language=en to_language=cs  

=head1 DESCRIPTION

This block copies a-trees into another zone.
The source a-tree is specified as usual using the parameters
C<language> and C<selector>.


=head1 PARAMETERS

=over

=item C<to_language>

Language of the new (target) a-trees.
Defaults to current C<language> setting.

=item C<to_selector>

Selector of the new (target) a-trees.
Default is the empty string.

=item C<flatten>

If this parameter is set, the target trees are made flat
(i.e. all nodes are set as direct children of the root)
and all attributes is_member are deleted.

=item C<align>

If this parameter is set, the target trees are aligned to the source ones.

=item C<keep_alignment_links>

If this parameter is set, both incoming and outgoing alignments are preserved in the 
new a-tree (to_selector). 

=back

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>
Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
