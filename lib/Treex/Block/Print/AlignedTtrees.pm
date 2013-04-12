package Treex::Block::Print::AlignedTtrees;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has '+language' => ( default => 'en' );
has language2 => ( isa => 'Treex::Type::LangCode', is => 'ro', default => 'cs' );
has selector2 => ( isa => 'Treex::Type::Selector', is => 'ro', default => q{} );


sub process_ttree {
    my ( $self, $ttree1 ) = @_;
    my $ttree2 = $ttree1->get_bundle()->get_zone( $self->language2, $self->selector2)->get_ttree();
    $self->print_tree($ttree1);
    $self->print_tree($ttree2);
    $self->print_alignment($ttree2);
    return;
}

sub print_tree {
    my ( $self, $ttree ) = @_;
    my @nodes = $ttree->get_descendants({ordered=>1});
    print { $self->_file_handle } '_ROOT ', join ' ', map {escape($_)} map {($_->formeme, $_->t_lemma)} @nodes;
    say { $self->_file_handle } "\t0 ", join ' ', map {my $p=$_->get_parent->ord*2; $p . ' ' . ($_->ord*2 - 1) } @nodes;
    return;
}

sub escape {
    my ($string) = $_;
    return '_' if !defined $string;
    $string =~ s/ /&#32;/g;
    $string =~ s/\(/&#40;/g;
    $string =~ s/\(/&#41;/g;
    $string =~ s/=/&#61;/g;
    return $string;
}

sub print_alignment {
    my ( $self, $ttree ) = @_;
    print { $self->_file_handle } '0-0';
    foreach my $node1 ($ttree->get_descendants({ordered=>1})){
        my ($node2) = $node1->get_aligned_nodes_of_type('int');
        next if ! $node2;
        my $o1 = $node1->ord * 2 - 1;
        my $o2 = $node2->ord * 2 - 1;
        print { $self->_file_handle } " $o2-$o1";
        $o1++; $o2++;
        print { $self->_file_handle } " $o2-$o1";
    }
    print { $self->_file_handle } "\n";
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Print::AlignedTtrees - interleaved formeme+t-lemma t-trees

=head1 DESCRIPTION

This block prints three lines for each sentence (bundle), e.g.:

  _ROOT n:subj John v:fin love    n:obj Mary    0  4  1  0  3  4  5
  _ROOT n:1    Jan  v:fin milovat n:4   Marie   0  4  1  0  3  4  5
  0-0 1-1 2-2 3-3 4-4 5-5 6-6
  _ROOT n:subj Shaw v:fin curse n:obj #PersPron n:poss #PersPron n:under+X breath v:for+ger start adv here  0 4 1 0 3 4 5 10 7 4 9 10 11 12 13
  _ROOT n:1 Shaw n:v+6 duch n:na+4 #PersPron v:fin zlobit_se drop #PersPron v:že+fin začít adv právě adv tady 0 8 1 8 3 8 5 0 7 12 9 8 11 16 13 12 15
  0-0 1-1 2-2 9-3 10-4 11-11 12-12 13-15 14-16

Formemes and t-lemmas are "interleaved", i.e. formemes are "on the edge to parent".
First line is English (formemes+t-lemmas \t dependencies), second Czech, third alignment.

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2012-2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
