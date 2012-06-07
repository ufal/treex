package Treex::Block::Print::EvalAlignedAtrees;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my %wrong_sentences;
my $all_nodes = 0;
my $err_nodes = 0;

sub process_anode {
    my ( $self, $node, $bundleNo ) = @_;
    $all_nodes++;
    my ($n) = $node->get_aligned_nodes;
    my ($a) = @$n;
    return if $node->get_parent->is_root && $a->get_parent->is_root;
    return $self->report_error($node, $bundleNo) if $node->get_parent->is_root || $a->get_parent->is_root;

    my ($pn)= $node->get_parent->get_aligned_nodes;
    return $self->report_error($node, $bundleNo) if !$pn;
    my ($pa)= @$pn;
    return $self->report_error($node, $bundleNo) if $a->parent != $pa;
    return;
}

sub report_error {
    my ($self, $node, $bundleNo) = @_;
    $err_nodes++;
    my $ad = $node->get_address;
    print STDERR "$ad\n" if !$wrong_sentences{$bundleNo};
    $wrong_sentences{$bundleNo} = 1;
    return;
}

sub process_end {
  my $errors = keys %wrong_sentences;
  my $score = 1 - ($err_nodes / $all_nodes);
  print STDERR "There were $errors wrong sentences. ($err_nodes / $all_nodes) UAS=$score\n";
}

1;
