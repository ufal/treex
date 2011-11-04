package Treex::Block::Read::MosesTrace;
use Moose;
use Treex::Core::Common;
use XML::Twig;
extends 'Treex::Block::Read::BaseTextReader';

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;
    my $document = $self->new_document();

    foreach my $line (split /\n/, $text) {
        my $twig=XML::Twig->new()->parse($line); # build DOM representation

        my $bundle = $document->create_bundle();
        my $zone   = $bundle->create_zone( $self->language, $self->selector );
        my $proot  = $zone->create_ptree();

        build($proot, $twig->root);

        #TODO $zone->set_sentence( $sentence );
    }
    return $document;
}

sub build {
  my $proot = shift;
  my $twigroot = shift;

  $proot->set_phrase($twigroot->att("label"));

  my @out = ();
  my $n = $twigroot->first_child();
  while (defined $n) {
    my $text = $n->pcdata();
    if (defined $text) {
      if ($text =~ /\S/) {
        $text =~ s/^\s+//;
        $text =~ s/\s+$//;
        foreach my $form (split /\s+/, $text) {
          my $new_terminal = $proot->create_terminal_child();
          $new_terminal->set_form($form);
          $new_terminal->set_lemma("???");
          $new_terminal->set_tag("???");
        }
      }
    } else {
      my $new_nonterm = $proot->create_nonterminal_child();
      build($new_nonterm, $n);
    }
    $n = $n->next_sibling();
  }
}

1;

__END__

=head1 NAME

Treex::Block::Read::MosesTrace

=head1 DESCRIPTION

Document reader for phrase-structure trees as produced by moses_chart -T and
converted to 'XML' by moses/scripts/analysis/extract-target-trees.py.

The trees are loaded to the p-layer.

=head1 ATTRIBUTES

=over

=item from

space or comma separated list of filenames

=back

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 SEE

L<Treex::Block::Read::BaseTextReader>
L<Treex::Core::Document>
L<Treex::Core::Bundle>

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
