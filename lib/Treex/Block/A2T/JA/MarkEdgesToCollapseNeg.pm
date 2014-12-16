package Treex::Block::A2T::JA::MarkEdgesToCollapseNeg;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_anode {
  my ( $self, $a_node ) = @_;
  my $lemma = $a_node->lemma;
  
  # Find every word "n" (ん) and "nai" (ない)
  return if $lemma !~ /^(ん|ない)$/;

  # Skip nodes that are already marked to be collapsed to parent.
  # Without this check we could rarely create a t-node with no lex a-node.
  return if $a_node->edge_to_collapse;

  my ($eparent) = $a_node->get_eparents() or next;
  
  my $p_tag = $eparent->tag || '_root';
  my $p_lemma = $eparent->lemma || '_root';

  # the parent should be either a verb, i-adjecive...
  if ( $p_tag =~ /^(Dōshi|Keiyōshi)/ ) {
    $a_node->set_is_auxiliary(1);
    $a_node->set_edge_to_collapse(1);
  }

  # ... or a copula
  elsif ( $p_tag =~ /^Jodōshi/ && $p_lemma =~ /^(です|だ)$/) {
    $a_node->set_is_auxiliary(1);
    $a_node->set_edge_to_collapse(1);
  }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::JA::MarkEdgesToCollapseNeg

=head1 DESCRIPTION

When building the t-layer for purposes of TectoMT transfer,
some additional rules are applied compared to preparing data for annotators.

Currently, there is just one rule for marking words "n" and "nai" as auxiliary
and collapsing to the governing verb
(grammateme C<negation> will be then used also for verbs).

=head1 AUTHORS

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
