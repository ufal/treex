package Treex::Block::Treelets::ExtractStrictTreelets;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my (%size1, %size2);

sub process_ttree{
    my ( $self, $root ) = @_;
    my $doc = $root->get_document();
    my @todo = ($root->get_children());   
    while (@todo){
        my $r1 = shift @todo;
        my $r2_id = $r1->wild->{ali_root};
        if (!$r2_id){
            push @todo, $r1->get_children();
            next;
        }
        my $r2 = $doc->get_node_by_id($r2_id);
        my ($treelet1_rf, $new_todo_rf) = $self->extract_treelet($r1);
        my ($treelet2_rf) = $self->extract_treelet($r2);
        $size1{scalar @$treelet1_rf}++;
        $size2{scalar @$treelet2_rf}++;
        $self->print_rule($treelet1_rf, $treelet2_rf);
        push @todo, @$new_todo_rf;
    }
    return;
}

sub extract_treelet {
    my ($self, $root) = @_;
    my @treelet = ($root);
    my @queue   = $root->get_children();
    my @todo    = ();
    
    while (@queue) {
        my $n = shift @queue;
        if ($n->wild->{ali_root}){
            push @todo, $n;
        } else {
            push @treelet, $n;
            push @queue, $n->get_children();
        }
    }
    return (\@treelet, \@todo);
}

sub print_rule {
    my ($self, $nodes1_rf, $nodes2_rf) = @_;
    my @nodes1 = sort {$a->ord <=> $b->ord} @$nodes1_rf;
    my @nodes2 = sort {$a->ord <=> $b->ord} @$nodes2_rf;
    my $i = 1;
    my %id2ord = map {$_->id, $i++} @nodes1;
    $i = 1;
    $id2ord{$_->id} = $i++ for @nodes2;
    my $src_nodes = join ' ', map {$_->t_lemma} @nodes1;
    my $src_deps  = join ' ', map {$id2ord{$_->get_parent->id}||0} @nodes1;
    my $trg_nodes = join ' ', map {$_->t_lemma} @nodes2;
    my $trg_deps  = join ' ', map {$id2ord{$_->get_parent->id}||0} @nodes2;
    my $alignment = join ' ', map {my ($al) = $_->get_aligned_nodes_of_type('int|rule-based');  $al ? $id2ord{$al->id}.'-'.$id2ord{$_->id} : ()} @nodes2;
    say "$src_nodes\t$src_deps\t$trg_nodes\t$trg_deps\t$alignment";
    return;
}

sub process_end {
    my $rep = "src treelet sizes:\n". join '', map {"$_=".($size1{$_}||0)."\n"} (1..10);
    $rep .= "trg treelet sizes:\n". join '', map {"$_=".($size2{$_}||0)."\n"} (1..10);
    warn $rep;
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Treelets::ExtractStrictTreelets - extract translation rules

=head1 DESCRIPTION

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
