package Treex::Block::Treelets::ExtractEdgeTreelets;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has alignment_direction => (
    is=>'ro',
    isa=>enum( [qw(src2trg trg2src)] ),
    default=>'trg2src',
    documentation=>'Default trg2src means that alignment goes *from* <language,selector> tree (which is the target language) to the source tree. src2trg means the opposite direction.',
);

my @MASKS = (
    [1,2,3], # L***
    [0,2,3], # *F**
    [2,3],   # LF**
    [0,3],   # *FL*
    [3],     # LFL*
    [0],     # *FLF
    [],      # LFLF
);
my @STARS = ('*') x 3;

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
    
    my $root = $self->alignment_direction eq 'trg2src' ? $root2 : $root1;
    my @queue = $root->get_children();
    while (@queue){
        my $node1 = shift @queue;
        push @queue, $node1->get_children();
        my @rule = $self->extract($node1);
        for my $mask (@MASKS){
            my @src = @rule[0..3];
            my @trg = @rule[4..7];
            @src[@$mask] = @STARS;
            @trg[@$mask] = @STARS;
            @trg = ('_') if any {$_ eq '_'} @trg;
            $self->print_rule(\@src, \@trg);
        }
        
    }

    return;
}

sub print_rule {
    my ($self, $src, $trg) = @_;
    say join ' ', @$src, @$trg;
    return;
}

sub extract {
    my ($self, $node1) = @_;
    my $parent1 = $node1->get_parent();
    my ($node2, $parent2) = @aligned{$node1, $parent1};
    my $n1L = $self->lemma($node1);
    my $n1F = $node1->formeme;
    my $p1L = $self->lemma($parent1);
    my $p1F = $parent1->formeme;
    my @src = ($n1L, $n1F, $p1L, $p1F);
    return (@src, '_', '_', '_', '_') if !$node2;
    my $n2L = $self->lemmapos($node2);
    my $n2F = $node2->formeme;
    return (@src, $n2L, $n2F, '_', '_') if !$parent2 || $node2->get_parent != $parent2;
    my $p2L = $self->lemmapos($parent2);
    my $p2F = $parent2->formeme;
    return (@src, $n2L, $n2F, $p2L, $p2F);
}

# Hack to include coarse-grained PoS tag for Czech lemma.
# $tnode->get_attr('mlayer_pos') is not filled in CzEng
sub lemmapos {
    my ($self, $tnode) = @_;
    my $lemma = $tnode->t_lemma;
    $lemma =~ s/ /&#32;/;
    my $anode = $tnode->get_lex_anode or return $lemma;
    my ($pos) = ( $anode->tag =~ /^(.)/ );
    return $lemma if !defined $pos;
    return "$lemma#$pos";
}

sub lemma {
    my ($self, $tnode) = @_;
    my $lemma = $tnode->t_lemma;
    $lemma =~ s/ /&#32;/;
    return $lemma;
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
