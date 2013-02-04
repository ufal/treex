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

    for my $root ($root1, $root2){
        $root->set_t_lemma('_ROOT');
        $root->set_formeme('_ROOT');
    }
    
    # Recursively (top-down DFS) extract all rules.
    my $root = $self->alignment_direction eq 'trg2src' ? $root2 : $root1;
    $self->process_subtree($root);

    return;
}


sub process_subtree{
    my ($self, $node1) = @_;
    my $node2 = $aligned{$node1};
    $self->extract_node($node1, $node2) if $node2;

    foreach my $child1 ($node1->get_children()){
        my $child2 = $aligned{$child1};
        if ($child2){
            my @nodes1 = ($node1, $child1);
            my @nodes2 = ($node2||(), $child2);
            my ($root2, $added_nodes2_rf) = Treex::Tool::Algorithm::TreeUtils::find_minimal_common_treelet(@nodes2);
            my @added1 = map {$aligned{$_}||()} @$added_nodes2_rf;

            # TODO we should extract bigger treelet with @nodes1 = ($node1, $child1, @added1)
            # but that would mean checking (recursively) if we reached idempotent sets of @nodes1 and @nodes2
            # @nodes1 ...= find_minimal_common_treelet(@nodes1);
            # @nodes2 ...= find_minimal_common_treelet(@aligned{@nodes1});
            # In this draft version, let's just forbid source treelets with more than two nodes.
            next if @added1;
            push @nodes2, @$added_nodes2_rf;
            $self->extract_edge($node1, $child1, \@nodes2);
        }
        
        $self->process_subtree($child1);
    }
    return;
}

sub extract_node {
    my ($self, $node1, $node2) = @_;
    print { $self->_file_handle } $node1->t_lemma.'|'.$node1->formeme."\t".$node2->t_lemma.'|'.$node2->formeme."\n";
    print { $self->_file_handle } $node1->t_lemma.'|*'."\t".$node2->t_lemma."|*\n";
    print { $self->_file_handle } '*|'.$node1->formeme."\t*|".$node2->formeme."\n";
    return;
}

sub extract_edge {
    my ($self, $node1, $child1, $nodes2_rf) = @_;
    my @nodes2 = sort {$a->ord <=> $b->ord} @$nodes2_rf;
    my $i = 1;
    my %node2ord = map {$_, $i++} @nodes2;
    @node2ord{($node1,$child1)} = (1,2);
    my $trg_deps  = join ' ', map {$node2ord{$_->get_parent||0}||0} @nodes2;
    my $alignment = join ' ', map {my $al = $aligned{$_}; $al ? $node2ord{$al}.'-'.$node2ord{$_} : ()} @nodes2;
    my ($node2,$child2) = map {$aligned{$_}||0} ($node1, $child1);

    for my $n1 ((0,1)){
        my $str_n1 = $node1->t_lemma;
        if ($n1) {$str_n1 .= '|' .$node1->formeme;}
        else { $str_n1 .= '|*';}
        for my $ch1 ((0,1)){
            my $str_ch1 = $ch1 ? ($child1->t_lemma) : '*';
            $str_ch1 .= '|' . $child1->formeme;
            my $trg_nodes = join ' ', map {
                my $str;
                if (!$n1 && $_==$node2){ $str = $self->lemma($_) . '|*';}
                elsif (!$ch1 && $_==$child2){ $str = '*|' . $_->formeme;}
                else {$str = $self->lemma($_) . '|' . $_->formeme;}
                $str;
            } @nodes2;
            print { $self->_file_handle } "$str_n1 $str_ch1\t$trg_nodes\t$trg_deps\t$alignment\n";
        }
    }
    return;
}

# Hack to include coarse-grained PoS tag for Czech lemma.
# $tnode->get_attr('mlayer_pos') is not filled in CzEng
sub lemma {
    my ($self, $tnode) = @_;
    my $lemma = $tnode->t_lemma;
    my $anode = $tnode->get_lex_anode or return $lemma;
    my ($pos) = ( $anode->tag =~ /^(.)/ );
    return $lemma if !defined $pos;
    return "$lemma#$pos";
}

1;

__END__

=encoding utf-8

=head1 NAME 

Treex::Block::Treelets::ExtractEdgeTreelets - extract translation rules

=head1 DESCRIPTION

extract translation rules where the source side is one node or one edge

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
