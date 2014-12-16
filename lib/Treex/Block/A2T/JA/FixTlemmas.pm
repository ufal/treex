package Treex::Block::A2T::JA::FixTlemmas;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Lexicon::JA;
extends 'Treex::Core::Block';

sub process_tnode {
  my ( $self, $node ) = @_;
  my $lex_a_node = $node->get_lex_anode or return;
  my $old_tlemma = $node->t_lemma;
  my $new_tlemma;

  if ( $old_tlemma eq "ん" || $old_tlemma eq "ない" ) {
    $new_tlemma = '#Neg';
  } 
  elsif ( $lex_a_node->tag =~ /^Meishi-Daimeishi/ ) {

    if ( Treex::Tool::Lexicon::JA::is_pers_pron($old_tlemma) ) {
      $new_tlemma = '#PersPron';
    }
  }

  if ($new_tlemma) {
    $node->set_t_lemma($new_tlemma);
  }
  
  return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::JA::FixTlemmas

=head1 DESCRIPTION

The attribute C<t_lemma> is corrected in specific cases: personal pronouns are represented
by #PersPron, etc.

=head1 AUTHOR

Dušan Variš <varis@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2008 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
