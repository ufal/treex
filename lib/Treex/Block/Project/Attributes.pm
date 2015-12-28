package Treex::Block::Project::Attributes;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has attributes => ( isa=>'Str', is=>'ro', required=>1, documentation => 'Space or comma separated list of attributes to be copied' );
has layer => ( isa=>'Treex::Type::Layer', is=>'ro', default=> 'a');
has alignment_type => (isa=>'Str', is=>'ro', default=>'.*', documentation=>'Use only alignments whose type is matching this regex. Default is ".*".');
has alignment_direction => (
    is=>'ro',
    isa=>enum( [qw(src2trg trg2src)] ),
    default=>'trg2src',
    documentation=>'Default trg2src means alignment from <language,selector> to <source_language,source_selector> tree. src2trg means the opposite direction.',
);

sub process_zone {
    my ( $self, $zone ) = @_;
    my $tree = $zone->get_tree($self->layer);

    foreach my $node ($tree->get_descendants({ordered=>1})) {
        my @src_nodes;
        if ($self->alignment_direction eq 'trg2src'){
            @src_nodes = $node->get_aligned_nodes_of_type($self->alignment_type);
            
        } else {
            @src_nodes = grep {$_->is_directed_aligned_to($node, {rel_types => [$self->alignment_type]})}
                         $node->get_referencing_nodes('alignment');
        }

        # Skip this node if it is unaligned.
        next if !@src_nodes;
        
        my $src_node = $self->choose_src_node(@src_nodes);
        foreach my $attr_name (split /[, ]/, $self->attributes){
            my $attr_value = $src_node->get_attr($attr_name);
            $node->set_attr($attr_name, $attr_value);
        }
    }
    return;
}

sub choose_src_node {
    my ( $self, @src_nodes) = @_;
    return $src_nodes[0];
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Project::Attributes - copy attributes via alignment

=head1 SYNOPSIS

 # Project (copy) t-lemma from en to cs t-trees.
 # Alignment links go from cs to en.
 Project::Attributes layer=t language=cs source_language=en attributes=t_lemma
 
 # Project form and tag from en to cs a-trees.
 # Alignment links go from en to cs.
 Project::Attributes layer=a language=cs source_language=en alignment_direction=src2trg attributes=form,tag

 # You can constrain types of alignment links to be used by specifying regex pattern.
 ... alignment_type=(manual|gdfa)
 
=head1 DESCRIPTION

Project (copy) various attributes (of a-nodes or t-nodes) via alignment links from one zone to another.

=head1 SEE ALSO

L<Treex::Block::Project::Tree>

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
