package Treex::Block::Read::CoNLLXfp;
use Moose;
use Treex::Core::Common;
use File::Slurp;
extends 'Treex::Block::Read::BaseCoNLLReader';

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;

    my $document = $self->new_document();
    foreach my $tree ( split /\n\s*\n/, $text ) {
        my @tokens  = split( /\n/, $tree );
        # Skip empty sentences (if any sentence is empty at all,
        # typically it is the first or the last one because of superfluous empty lines).
        next unless(@tokens);
        my $bundle  = $document->create_bundle();
        my $zone    = $bundle->create_zone( $self->language, $self->selector );
        my $aroot   = $zone->create_atree();
        my @parent_ids = (0);
        my @nodes   = ($aroot);
        my $sentence;
        my $newnode = undef;
        my %id2ord = ( 0 => 0 );
        my $lastord = 0;
        foreach my $token (@tokens) {
            next if $token =~ /^\s*$/;
            my ( $id, $form, $lemma, $cpos, $pos, $feat, $head, $deprel ) = split( /\t/, $token );
            $id2ord{$id} = ++$lastord;
            
            # handle previous newnode
            # !!! the fact that several tokens belong to the same word is now
            # captured by their no_space_after being 1, so that the tokens are
            # glued together... maybe not a perfect solution but one that was
            # quickly at hand and efficient enough...
            if ( defined $newnode ) {
                my ( $token, $part ) = split /\./, $id;
                if ( $part eq '0' ) {
                    # new word starts here;
                    # add a space after the previous word form
                    $sentence .= ' ';
                    # $newnode->set_no_space_after(0); # = the default
                }
                else {
                    # this token is a continuation of the current word
                    $newnode->set_no_space_after(1);
                }
                push @nodes, $newnode;
            }
            
            # create new newnode
            $newnode = $aroot->create_child();
            $newnode->shift_after_subtree($aroot);
            $newnode->set_form($form);
            $newnode->set_lemma($lemma);
            $newnode->set_tag($pos);
            $newnode->set_conll_cpos($cpos);
            $newnode->set_conll_pos($pos);
            $newnode->set_conll_feat($feat);
            $newnode->set_conll_deprel($deprel);
            $sentence .= $form;
            push @parent_ids, $head;
        }
        # handle last newnode
        push @nodes, $newnode;

        foreach my $i ( 1 .. $#nodes ) {
            $nodes[$i]->set_parent( $nodes[ $id2ord{$parent_ids[$i]} ] );
        }
        $sentence =~ s/\s+$//;
        $zone->set_sentence($sentence);
    }

    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::CoNLLXfp

=head1 DESCRIPTION

For Hebrew, where ords are floating point numbers to represent token
segmentation, e.g.

  1.0 יצאתי
  2.0 מ
  2.1 ה
  2.2 בית

Otherwise identical to CoNLL format.
Each token is on separated line in the following format:
ord<tab>form<tab>lemma<tab>cpos<tab>pos<tab>features<tab>head<tab>deprel
Sentences are separated with blank line.
The sentences are stored into L<bundles|Treex::Core::Bundle> in the 
L<document|Treex::Core::Document>.

=head1 ATTRIBUTES

=over

=item from

space or comma separated list of filenames

=item lines_per_doc

number of sentences (!) per document

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

Rudolf Rosa

David Mareček

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
