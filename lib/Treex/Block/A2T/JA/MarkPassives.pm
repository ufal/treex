package Treex::Block::A2T::Ja::MarkPassives;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

sub process_tnode {
  my ( $self, $t_node ) = @_;

  my $lex_a_node = $t_node->get_lex_anode();
  return if !defined $lex_a_node;   # gracefully handle e.g. generated nodes
  my @aux_a_nodes = $t_node->get_aux_anodes();

  # passive is indicated by auxiliary wordform "reru" (れる) or "rareru" (られる)
  if ( $lex_a_node->tag =~ /^Dōshi/ && grep { $_->lemma =~ /^(れる|られる)$/) } @aux_a_nodes ) {
    
    $t_node->set_is_passive(1);
    $t_node->set_gram_diathesis('pas');

  }
  else {

    $t_node->set_is_passive(undef);
    $t_node->set_gram_diathesis('act') if ( $lex_a_node->tag =~ /^Dōshi/ );

  }
  
  return 1;
}

1;

=encoding utf-8

=head1 NAME

Treex::Block::A2T::JA::MarkPassives

=head1 DESCRIPTION

Japanese t-nodes corresponding to passive verb expressions are marked with a value of 1 in the C<is_passive> attribute.

The C<diathesis> grammateme is set to C<pas> for such nodes and C<act> for other verbal t-nodes.  

=back

=head1 AUTHOR

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008-2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
