package Treex::Block::Read::CoNLL2009;
use Moose;
use Treex::Core::Common;
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
        my @parents = (0);
        my @nodes   = ($aroot);
        my $sentence;
        foreach my $token (@tokens) {
            next if $token =~ /^\s*$/;

            # Warning: the PHEAD and PDEPREL occur in both CoNLL 2009 and 2006 but have totally different meanings!
            # We could call them differently but we do not use their values so far so it does not make a difference.
            my ( $id, $form, $lemma, $plemma, $postag, $ppos, $feats, $pfeat, $head, $phead, $deprel, $pdeprel, $fillpred, $pred, @apreds ) = split( /\s+/, $token );
            my $newnode = $aroot->create_child();
            $newnode->shift_after_subtree($aroot);
            $newnode->set_form($form);
            $newnode->set_lemma($lemma);
            $newnode->set_tag($postag);
            $newnode->set_conll_cpos($postag);
            $newnode->set_conll_pos($postag);
            $newnode->set_conll_feat($feats);
            $newnode->set_conll_deprel($deprel);
            if ($fillpred ne '_'){ # save CoNLL predicate ID to wild attribute
                $newnode->wild->{conll_pred} = $pred;
            }
            $sentence .= "$form ";
            push @nodes,   $newnode;
            push @parents, $head;
        }
        foreach my $i ( 1 .. $#nodes ) {
            $nodes[$i]->set_parent( $nodes[ $parents[$i] ] );
        }
        $sentence =~ s/\s+$//;
        $zone->set_sentence($sentence);
    }

    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::CoNLL2009

=head1 DESCRIPTION

Document reader for the CoNLL 2009 (and 2008) format.
Each token is on separated line in the following format:
ord<tab>form<tab>lemma<tab>plemma<tab>postag<tab>ppostag<tab>feats<tab>pfeats<tab>head<tab>phead<tab>deprel<tab>pdeprel<tab>semantic features
The number and order of columns differs from that of CoNLL-X!
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

David Mareček and Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011-2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
