package Treex::Block::Read::CoNLL2012;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseCoNLLReader';

has 'use_p_attribs' => ( is => 'ro', isa => 'Bool', default => 0 );

sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    log_debug "Processing filename: ". $self->from->current_filename;
    return if !defined $text;

    my $document = $self->new_document();
    my $text_no_comments = join "\n", (grep {$_ !~ /^\#/} (split /\n/, $text));
    foreach my $tree ( split /\n\s*\n/, $text_no_comments ) {
        next if ($tree =~ /^\#/);
        my @tokens  = split( /\n/, $tree );
        # Skip empty sentences (if any sentence is empty at all,
        # typically it is the first or the last one because of superfluous empty lines).
        next unless(@tokens);
        my $bundle  = $document->create_bundle();
        # The default bundle id is something like "s1" where 1 is the number of the sentence.
        # If the input file is split to multiple Treex documents, it is the index of the sentence in the current output document.
        # But we want the input sentence number. If the Treex documents are later exported to one file again, the sentence ids should remain unique.
        my $sentid  = $self->sent_in_file() + 1;
        $bundle->set_id('s'.$sentid);
        $self->set_sent_in_file($sentid);
        my $zone    = $bundle->create_zone( $self->language, $self->selector );
        my $aroot   = $zone->create_atree();
        my $sentence;
        my $doc_part_for_bundle;
        foreach my $token (@tokens) {
            next if $token =~ /^\s*$/;

            my ( $doc_id, $doc_part, $ord, $form, $postag, $parsebit, $pred_lemma, $pred_frame_id, $word_sense, $speaker, $nes, @rest ) = split( /\s+/, $token );
            my $coref_info = pop @rest;
            my @pred_args = @rest;

            my $newnode = $aroot->create_child();
            $newnode->shift_after_subtree($aroot);
            $newnode->set_form($form);
            $newnode->set_tag($postag);

            my ($coref_start, $coref_end) = _extract_coref_info($coref_info);


            $newnode->wild->{coref_mention_start} = $coref_start if (@$coref_start);
            $newnode->wild->{coref_mention_end} = $coref_end if (@$coref_end);

            $doc_part_for_bundle = $doc_part;
            $sentence .= "$form ";
        }
        
        #TODO this attribute where a block (or a part) within a document is specified should be renamed to hold a more generic name
        $bundle->set_attr('czeng/blockid', $doc_part_for_bundle);
        
        $sentence =~ s/\s+$//;
        $zone->set_sentence($sentence);
    }

    return $document;
}

sub _extract_coref_info {
    my ($coref_info_str) = @_;
    return ([], []) if (!defined $coref_info_str || $coref_info_str =~ /^-?$/);
    my @coref_info = split /\|/, $coref_info_str;
    my @start_idxs = map {$_ =~ /\((\d+)/; $1} grep {$_ =~ /\(\d+/} @coref_info;
    my @end_idxs = map {$_ =~ /(\d+)\)/; $1} grep {$_ =~ /\d+\)/} @coref_info;
    return (\@start_idxs, \@end_idxs);
}


1;

__END__

=head1 NAME

Treex::Block::Read::CoNLL2012

=head1 DESCRIPTION

Document reader for the CoNLL 2012 format.
This format has been used for multiple Shared Tasks in Coreference Resolution, especially the CoNLL 2012 Shared Task.
Each token is on separated line in the following format:

1   Document ID     This is a variation on the document filename
2   Part number     Some files are divided into multiple parts numbered as 000, 001, 002, ... etc.
3   Word number     
4   Word itself     This is the token as segmented/tokenized in the Treebank. Initially the *_skel file contain the placeholder [WORD] which gets replaced by the actual token from the Treebank which is part of the OntoNotes release.
5   Part-of-Speech  
6   Parse bit   This is the bracketed structure broken before the first open parenthesis in the parse, and the word/part-of-speech leaf replaced with a *. The full parse can be created by substituting the asterix with the "([pos] [word])" string (or leaf) and concatenating the items in the rows of that column.
7   Predicate lemma     The predicate lemma is mentioned for the rows for which we have semantic role information. All other rows are marked with a "-"
8   Predicate Frameset ID   This is the PropBank frameset ID of the predicate in Column 7.
9   Word sense  This is the word sense of the word in Column 3.
10  Speaker/Author  This is the speaker or author name where available. Mostly in Broadcast Conversation and Web Log data.
11  Named Entities  These columns identifies the spans representing various named entities.
12:N    Predicate Arguments     There is one column each of predicate argument structure information for the predicate mentioned in Column 7.
N   Coreference     Coreference chain information encoded in a parenthesis structure.

Sentences are separated with blank line.
The sentences are stored into L<bundles|Treex::Core::Bundle> in the L<document|Treex::Core::Document>.

In its current implementation, definitely not all information is stored so far.

See L<http://conll.cemantix.org/2012>.

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
