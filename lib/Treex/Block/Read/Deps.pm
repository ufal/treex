package Treex::Block::Read::Deps;
use Moose;
use Treex::Core::Common;
use File::Slurp;
extends 'Treex::Block::Read::BaseTextReader';

#TODO: add checks for invalid input format
sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;

    my $document = $self->new_document();
    my @lines = split /\n/, $text;
    while (@lines){
        my $sentence = shift @lines;
        my $empty = shift @lines;
        my $deps = shift @lines;
        $empty = shift @lines if @lines;

        my $bundle  = $document->create_bundle();
        my $zone    = $bundle->create_zone( $self->language, $self->selector );
        my $aroot   = $zone->create_atree();
        my @parents = (0);
        my @nodes   = ();

        foreach my $token (split / /, $sentence){
            $token =~ s/^\d+://;
            my ($form, $tag, $cpos) = split /\//, $token;
            my $newnode = $aroot->create_child();
            $newnode->shift_after_subtree($aroot);
            $newnode->set_form($form);
            $newnode->set_lemma(lc $form);
            $newnode->set_tag($tag);
            $newnode->set_conll_cpos($cpos);
            push @nodes, $newnode;
        }

        $deps =~ s/^deps: //;
        foreach my $edge (split / /, $deps){
            my ($parent_id, $child_id) = split /-/, $edge;
            log_fatal "invalid edge $edge for $sentence"
                if ($parent_id > @nodes) || ($child_id > @nodes);
            my ($parent, $child) = @nodes[$parent_id, $child_id];
            $child->set_parent($parent);
        }

        $zone->set_sentence(join ' ', map {$_->form} @nodes);
    }

    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::Deps

=head1 DESCRIPTION

Document reader for a special format of dependency trees which looks like

  0:John/nnp/Noun 1:loves/vb/Verb 2:Mary/nnp/Noun
  
  deps: 1-0 1-2
  
  0:second/jj/Adjective 1:sentence/nn/Noun
  
  deps: 1-0

=head1 ATTRIBUTES

=over

=item from

space or comma separated list of filenames

=item lines_per_doc

number of lines (!) per document
Note that one sentence (bundle) takes four lines.

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

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
