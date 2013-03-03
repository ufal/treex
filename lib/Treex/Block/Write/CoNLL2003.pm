package Treex::Block::Write::CoNLL2003;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Write::BaseTextWriter';

has 'cols'              => ( is => 'rw', 'isa' => 'Int', default => 4 );
has 'conll_labels'      => ( is => 'rw', 'isa' => 'Bool', default => 0 );

sub _guess_conll_label {
  my ( $label ) = @_;

  my %CONLL_LABELS = ( 'PER' => 1, 'LOC' => 1, 'ORG' => 1, 'MISC' => 1, 'O' => 1 );
  
  return $label if exists $CONLL_LABELS{$label};
  # TODO: My first guess about transforming fine-grained 2-character Czech NE
  # labels to CoNLL2003 labels.
  return 'O' if $label =~ /^[acnoqt]/;
  return 'PER' if $label =~ /^p/;
  return 'LOC' if $label =~ /^g/;
  return 'ORG' if $label =~ /^[im]/;
}

sub process_atree {
    my ( $self, $atree ) = @_;

    my $prev_ne_type = "O";
    my $prev_n_node_id = "";
    foreach my $a_node ( $atree->get_descendants( { ordered => 1 } ) ) {
      # Mark start of new document (news article)
      if ($a_node->wild->{docstart}) {
        print { $self->_file_handle } "-DOCSTART- -X- ". ($self->cols == 5 ? "-X- " : "") . "O O\n\n";
      }

      my $str = $a_node->form." ";
      $str .= ($self->cols == 5 ? $a_node->lemma." " : "");
      $str .= $a_node->tag." ";

      # TODO: parametrized "dummy" string when conll chunk is not present
      $str .= $a_node->wild->{conll_chunk} ? $a_node->wild->{conll_chunk} : "_";
      $str .= " ";
      
      my $n_node = $a_node->n_node();
      
      if (not $n_node) {
        $str .= "O";
        $prev_ne_type = "O";
        $prev_n_node_id = "";
      }
      else {
        my $ne_type = $self->conll_labels ? _guess_conll_label($n_node->ne_type) : $n_node->ne_type;
        if ($ne_type eq "O") {
          $str .= $ne_type;
        }
        else {
          if ($prev_ne_type ne "O" 
              and $prev_n_node_id ne $n_node->id
              and $prev_ne_type eq $ne_type) {
            $str .= "B-" . $ne_type;
          }
          else {
            $str .= "I-" . $ne_type;
          }
        }
        $prev_ne_type = $ne_type;
        $prev_n_node_id = $n_node->id;
      }
      print { $self->_file_handle } $str."\n";
    }
    print { $self->_file_handle } "\n";
    $prev_ne_type = "O";
    $prev_n_node_id = "";
    return;
}

1;

__END__

=head1 NAME

Treex::Block::Write::CoNLL2003

=head1 DESCRIPTION

Document writer for CoNLL2003 format, one token per line.
The CoNLL2003 NER shared task format is described here:
http://www.cnts.ua.ac.be/conll2003/ner/

=back

=head1 PARAMETERS

=over

=item cols

Number of columns, either 4 (form, tag, chunk, ne_type => e.g. CoNLL2003
English data) or 5 (form, lemma, tag, chunk, ne_type => e.g. CoNLL2003 German
data). Default is 4.

=item conll_labels

If 1, the system prints CoNLL2003 NE type labels, one of PER, LOC, ORG, MISC.
Default is 0, that is, original labels are printed.

=head1 METHODS

=over

=item process_document

Saves the document.

=back

=head1 AUTHOR

Jana Straková

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
