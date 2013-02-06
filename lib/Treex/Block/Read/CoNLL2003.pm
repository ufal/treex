package Treex::Block::Read::CoNLL2003;
use Moose;
use Treex::Core::Common;
use File::Slurp;
extends 'Treex::Block::Read::BaseTextReader';

has 'read_gold' => ( is => 'rw', isa => 'Bool', default => 1 );

sub _add_entity {
  my ($zone, $a_nodes_ref, $type) = @_;
 
  my $n_root = $zone->has_ntree() ? $zone->get_ntree() : $zone->create_ntree();

  my @names = map { $_->form} @{$a_nodes_ref};
  my $n_node = $n_root->create_child(
    ne_type => $type,
    normalized_name => join (" ", @names),
  );
  $n_node->set_anodes( @{$a_nodes_ref} );
}

sub _process_sentence {
  my ($self, $document, $sentence, $docstart) = @_;
  
  return if not @{$sentence};

  my $bundle  = $document->create_bundle();
  my $zone    = $bundle->create_zone( $self->language, $self->selector );
  my $a_root   = $zone->create_atree();
  
  my @entity_anodes;
  my $prev_type = 'O';
  my $sentence_text;
  my $ord = 0;
  foreach my $token (@{$sentence}) {
    my @cols = split (/ /, $token);
    my $ncols = @cols;
    
    my ($form, $lemma, $tag, $chunk, $ne_type);
    ($form, $lemma, $tag, $chunk, $ne_type) = @cols if $ncols == 5;
    ($form, $lemma, $chunk, $ne_type) = @cols if $ncols == 4; 

    my $newnode = $a_root->create_child();
    $newnode->shift_after_subtree($a_root);
    $newnode->set_form($form);
    $newnode->set_lemma($lemma);
    $newnode->set_tag($tag) if $ncols == 5;
    $sentence_text .= "$form ";
    $newnode->set_parent($a_root);

    if ($docstart) { # mark beginning of new document (e.g. news article)
      $newnode->wild->{docstart} = 1;
      $docstart = 0;
    }

    # skip creating n-tree if not interested in NE labels
    next if not $self->read_gold;

    if ($ne_type eq 'O') {      # no entity here
      if ($prev_type ne 'O') {  # previous was entity => flush
        _add_entity($zone, \@entity_anodes, $prev_type);
        @entity_anodes = ();
      }
      $prev_type = 'O';
    }
    else {      # entity here (B- or I-)
      my ($prefix, $type) = split /-/, $ne_type;
      if ($prefix eq 'B'
          or $prev_type ne 'O' and $prev_type ne $type) {
        _add_entity($zone, \@entity_anodes, $prev_type);
        @entity_anodes = ();
      }
      push @entity_anodes, $newnode;
      $prev_type = $type;
    }
  }
  $sentence =~ s/\s+$//;
  $zone->set_sentence($sentence_text);
}

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;

    my $document = $self->new_document();
    my @lines = split /\n/, $text;
    my @sentence;
    my $docstart = 0;
    foreach my $line (@lines) {
      chomp $line;
      if ($line ne "" and not $line =~ /-DOCSTART-/) {
        push @sentence, $line;
      }
      if ($line =~ /-DOCSTART-/) {
        $docstart = 1;
      }
      if ($line eq "" and @sentence) {
        _process_sentence($self, $document, \@sentence, $docstart);
        @sentence = ();
        $docstart = 0;
      }
    }
    _process_sentence($self, $document, \@sentence, $docstart);

    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::CoNLL2003

=head1 DESCRIPTION

Document reader for CoNLL 2003 format.
CoNLL 2003 shared task was named entity recognition.

Each token is on separated line in either of the two following formats:
form<tab>lemma<tab>chunk<tab>named_entity (English data)
form<tab>lemma<tab>pos_tag<tab>chunk<tab>named_entity (German data)

Sentences are separated with blank line.
The sentences are stored into L<bundles|Treex::Core::Bundle> in the 
L<document|Treex::Core::Document>.

=head1 ATTRIBUTES

=over

=item from

space or comma separated list of filenames

=item read_gold

Boolean attribute, if true, gold labels (last column) will be read in and saved
in n-trees, if false, gold labels are ignored and no n-trees will be created.
Default is true.

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

Jana Straková

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
