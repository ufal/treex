package Treex::Block::Treelets::ExtractEdgeTreelets;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';
use Treex::Tool::Algorithm::TreeUtils;

has alignment_direction => (
    is=>'ro',
    isa=>enum( [qw(src2trg trg2src)] ),
    default=>'trg2src',
    documentation=>'Default trg2src means that alignment goes *from* <language,selector> tree (which is the target language) to the source tree. src2trg means the opposite direction.',
);


my (%aligned, %size1, %size2);

sub process_ttree{
    my ( $self, $root1 ) = @_;
    my $root2;

    # Precompute alignment in both directions for speed
    %aligned = ();
    foreach my $node1 ($root1->get_descendants()){
        my ($node2) = $node1->get_aligned_nodes_of_type('int|rule-based');
        if ($node2){
            $aligned{$node1} = $node2;
            $aligned{$node2} = $node1;
            if (!$root2){
                $root2 = $node2->get_root();
            }
        }
    }
    return if !$root2;
    $aligned{$root1} = $root2;
    $aligned{$root2} = $root1;
    
    # Recursively (top-down DFS) extract all rules.
    my $root = $self->alignment_direction eq 'trg2src' ? $root2 : $root1;
    $self->process_subtree($root);

    return;
}


sub process_subtree{
    my ($self, $node1) = @_;
    my $node2 = $aligned{$node1};
    $self->print_rule([$node1], [$node2]) if $node2;

    foreach my $child1 ($node1->get_children()){
        my $child2 = $aligned{$child1};
        if ($child2){
            my @nodes1 = ($node1, $child1);
            my @nodes2 = ($node2||(), $child2);
#say "in: ".join(" ,", map {$_->t_lemma//'ROOT'} @nodes2);
            my ($root2, $added_nodes2_rf) = Treex::Tool::Algorithm::TreeUtils::find_minimal_common_treelet(@nodes2);
#say "root=".($root2->t_lemma//'ROOT');
#say 'added='.join(",", map {$_->t_lemma//'ROOT'} @$added_nodes2_rf);
            my @added1 = map {$aligned{$_}||()} @$added_nodes2_rf;

            # TODO we should extract bigger treelet with @nodes1 = ($node1, $child1, @added1)
            # but that would mean checking (recursively) if we reached idempotent sets of @nodes1 and @nodes2
            # @nodes1 ...= find_minimal_common_treelet(@nodes1);
            # @nodes2 ...= find_minimal_common_treelet(@aligned{@nodes1});
            # In this draft version, let's just forbid source treelets with more than two nodes.
            next if @added1;
            push @nodes2, @$added_nodes2_rf;
            $self->print_rule(\@nodes1, \@nodes2);
        }
        
        $self->process_subtree($child1);
    }
    return;
}

sub extract_rule {
    my ($self, $nodes1_rf, $nodes2_rf) = @_;
    my @nodes1 = sort {$a->ord <=> $b->ord} @$nodes1_rf;
    my @nodes2 = sort {$a->ord <=> $b->ord} @$nodes2_rf;
}

sub print_rule {
    my ($self, $nodes1_rf, $nodes2_rf) = @_;
    my @nodes1 = sort {$a->ord <=> $b->ord} @$nodes1_rf;
    my @nodes2 = sort {$a->ord <=> $b->ord} @$nodes2_rf;
    $size1{scalar @nodes1}++;
    $size2{scalar @nodes2}++;
    my $i = 1;
    my %node2ord = map {$_, $i++} @nodes1;
    $i = 1;
    $node2ord{$_} = $i++ for @nodes2;
    my $src_nodes = join ' ', map {$_->t_lemma//'ROOT'} @nodes1;#/
    my $src_deps  = join ' ', map {$node2ord{$_->get_parent||0}||0} @nodes1;
    my $trg_nodes = join ' ', map {$_->t_lemma//'ROOT'} @nodes2;#/
    my $trg_deps  = join ' ', map {$node2ord{$_->get_parent||0}||0} @nodes2;
    my $alignment = join ' ', map {my $al = $aligned{$_}; $al ? $node2ord{$al}.'-'.$node2ord{$_} : ()} @nodes2;
    print { $self->_file_handle } "$src_nodes\t$src_deps\t$trg_nodes\t$trg_deps\t$alignment\n";
    return;
}

#sub process_end {
#    my $rep = "src treelet sizes:\n". join '', map {"$_=".($size1{$_}||0)."\n"} (1..5);
#    $rep .= "trg treelet sizes:\n". join '', map {"$_=".($size2{$_}||0)."\n"} (1..5);
#    warn $rep;
#}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Treelets::ExtractEdgeTreelets - extract translation rules

=head1 DESCRIPTION

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
