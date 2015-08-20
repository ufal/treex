package Treex::Block::Read::Vertical;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
use File::Slurp;
extends 'Treex::Block::Read::BaseTextReader';

#------------------------------------------------------------------------------
# Reads and returns a portion of input that corresponds to one document.
# If there are no restrictions on the numer of sentences per document, it reads
# the next input file. If there are such restrictions, it reads the required
# number of sentences.
#------------------------------------------------------------------------------
sub next_document_text
{
    my ($self) = @_;
    # If there is no limit on the number of sentences per document, read one file.
    if($self->is_one_doc_per_file())
    {
        return $self->from()->next_file_text();
    }
    # Otherwise read the specified number of sentences.
    ###!!! Will it read across file boundary? It seems that it won't.
    my $text = '';
    my $nsent = 0;
    LINE:
    while(1)
    {
        my $line = $self->from()->next_line();
        # No more lines in this file?
        if(!defined($line))
        {
            return if $text eq '' && !$self->from()->has_next_file();
            last LINE;
        }
        # New sentence?
        if($line =~ m/^<s[ >]/)
        {
            $nsent++;
            return $text if ($nsent == $self->lines_per_doc());
        }
        $text .= $line;
    }
    return $text;
}

#------------------------------------------------------------------------------
# Creates a new Treex document, reads its contents from the input vertical
# file, and returns it.
#------------------------------------------------------------------------------
sub next_document
{
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if(!defined($text));
    my $document = $self->new_document();
    foreach my $sentence (split(/<\/s>/, $text))
    {
        # Split sentence to lines, exclude empty and markup lines.
        my @tokens = grep {!m/^\s*$/ && !m/^</} (split(/\r?\n/, $sentence));
        # Skip empty sentences.
        next unless(@tokens);
        my $bundle  = $document->create_bundle();
        my $zone    = $bundle->create_zone( $self->language, $self->selector );
        my $root    = $zone->create_atree();
        my @forms;
        foreach my $token (@tokens)
        {
            $token =~ s/^\s+//;
            $token =~ s/\s+$//;
            my ($form, $tag, $lemma) = split(/\s+/, $token);
            if(defined($form))
            {
                my $node = $root->create_child();
                $node->set_form($form);
                $node->set_tag($tag) if(defined($tag));
                $node->set_lemma($lemma) if(defined($lemma));
                push(@forms, $form);
            }
        }
        $zone->set_sentence(join(' ', @forms));
    }
    return $document;
}

1;

__END__

=head1 NAME

Treex::Block::Read::Vertical

=head1 DESCRIPTION

The “vertical” corpus format was defined in 1990s at the University of Stuttgart.
Its various flavors are popular with many corpus tools and services
(e.g. the L<SketchEngine|https://www.sketchengine.co.uk/xdocumentation/wiki/SkE/PrepareText>).
It is similar to the CoNLL format in that every token has its own line, and
there may be several columns with various attributes of the token.
Unlike the CoNLL format, sentences are not delimited by empty lines.
Instead, a line may contain an SGML/XML tag. Such a line is not considered
a token but it may introduce a new sentence, paragraph, document etc.

This reader currently ignores all markup except for the sentence delimiters,
<s> and </s>. It also expects one to three attributes of each token, in this
order: 1. form; 2. tag; 3. lemma.
(This decision follows from the only corpus (Maltese) we now have in this format.
It can be extended and customized when the need arises.)

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

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
