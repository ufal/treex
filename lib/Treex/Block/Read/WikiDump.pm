package Treex::Block::Read::WikiDump;
use Moose;
use XML::LibXML::Reader;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader'; # možná raději jenom BaseReader?



has _xml_reader =>
(
    isa    => 'XML::LibXML::Reader',
    is     => 'rw',
    writer => '_set_xml_reader'
);



###!!! Debug only: How many documents have we read before?
has n => (is => 'rw', default => 0);



#------------------------------------------------------------------------------
# Initializes the module.
#------------------------------------------------------------------------------
sub BUILD
{
    my ($self) = @_;
    $self->set_is_one_doc_per_file(0);
    return;
}



#------------------------------------------------------------------------------
# Takes the next Wikipedia dump file from the input and reads it. Despite the
# name of the method, reading one file may result in many Treex documents!
#------------------------------------------------------------------------------
sub next_document
{
    my $self = shift;
    ###!!! If we had enough, do not read anything.
    ###!!!return if($self->n()>=10);
    # If there is a reader with unfinished XML file, use it.
    my $reader = $self->_xml_reader();
    if(!defined($reader))
    {
        # Get next input filename and create a reader for it.
        my $filename = $self->next_filename();
        # If there are no more filenames we have finished reading. Return undef.
        return if(!defined($filename));
        # Create reader for the file.
        log_info("Processing file: $filename");
        $reader = XML::LibXML::Reader->new(location => $filename);
        $self->_set_xml_reader($reader);
    }
    # Look for the next <page> element within the currently open input file.
    # One <page>...</page> corresponds to one document for us.
    my %page;
    my $ok = 0;
    while(!$ok)
    {
        my $result = $reader->nextElement('page');
        if($result>0) # success
        {
            $ok = 1;
            # Read XML nodes in the subtree of <page> and process them.
            while($reader->read())
            {
                # Get out of the loop once the </page> end tag is reached.
                last if($reader->name() eq 'page' && $reader->nodeType() == XML_READER_TYPE_END_ELEMENT);
                # Read the attributes of the page.
                if($reader->nodeType() == XML_READER_TYPE_ELEMENT)
                {
                    if($reader->name() =~ m/^(title|ns|text)$/)
                    {
                        $page{$reader->name()} = $reader->readInnerXml();
                    }
                    elsif($reader->name() eq 'redirect')
                    {
                        $page{redirect} = 1;
                    }
                }
            }
        }
        elsif($result==-1) # error
        {
            log_fatal('Error reading XML');
        }
        else # no more pages
        {
            return; ###!!! We should try to open a new filename!
        }
        # Try to read another page if the page has empty text
        # or it is a redirect or it is not in the main namespace of Wikipedia (we do not want Categories, Templates etc.)
        if($page{redirect} || $page{ns}!=0 || $page{text} =~ m/^\s*$/s)
        {
            $ok = 0;
            %page = ();
        }
    }
    # Create a new Treex document for the page.
    my $document = $self->new_document();
    if($page{title})
    {
        my $filestem = $page{title};
        $filestem =~ s/\s+/_/g;
        # Filename must not contain slashes but there are article titles that do, e.g. '/dev/random'.
        $filestem =~ s:/:_:g;
        # Filenames beginning with dash are difficult to work with in shell (dash elsewhere in the name is OK).
        $filestem =~ s:^-:_:g;
        $document->set_file_stem($filestem);
        $document->set_file_number('');
    }
    my $zone = $document->create_zone($self->language(), $self->selector());
    #$zone->set_text($self->decode_entities($page{text}));
    $zone->set_text(
        $self->normalize_line_breaks(
        $self->remove_mediawiki(
        $self->decode_entities($page{text}))));
    ###!!! Counter of read documents for debug purposes.
    $self->set_n($self->n()+1);
    return $document;
}



#------------------------------------------------------------------------------
# Decodes entities in text. Should we use an existing module instead?
# Which one?
#------------------------------------------------------------------------------
sub decode_entities
{
    my $self = shift;
    my $text = shift;
    $text =~ s/&lt;/</g;
    $text =~ s/&gt;/>/g;
    $text =~ s/&amp;/&/g;
    return $text;
}



#------------------------------------------------------------------------------
# Removes MediaWiki syntax from text.
#------------------------------------------------------------------------------
sub remove_mediawiki
{
    my $self = shift;
    my $wiki = shift;
    # Remove HTML comments.
    $wiki =~ s/<!--.*?-->//gs;
    # Remove templates. Do not attempt to expand them.
    $wiki = $self->remove_nested($wiki, '\{\{', '\}\}', '{}');
    # Remove tables.
    $wiki = $self->remove_nested($wiki, '\{\|', '\|\}', '{}');
    $wiki = $self->remove_nested($wiki, '<table.*?>', '</table>');
    # Remove image galleries.
    $wiki =~ s:<gallery( .*?)??>.*?</gallery>::igs;
    # Convert headings to paragraphs.
    $wiki =~ s/^(==+)\s*(.+?)\s*\1$/\n$2\n/gm;
    # Convert list items to paragraphs.
    $wiki =~ s/^([-*:].*)$/\n$1\n/gm;
    # One level of nesting is possible in links: a link to image contains file caption, the caption can contain phrases that link to articles.
    # Remove nested links within image captions.
    my $nobracket = '[^\[\]]';
    my $nopipe = '[^|]';
    my $nobracketpipe = '[^\[\|\]]';
    while($wiki =~ s/(\[\[$nobracketpipe+\|$nobracket*)\[\[($nobracket*)\]\]/$1$2/s) {}
    # Links with multiple vertical bars probably refer to pictures.
    # Replace them by a uniform tag. (We should not remove them tracelessly because they could represent a special character in text.)
    $wiki =~ s/\[\[$nobracketpipe*\|$nobracketpipe*\|$nobracket*?\]\]/<img>/gs;
    # Remove links to other namespaces: remaining images, categories, old interwiki links etc.
    # If the text contains a "normal link" (i.e. a phrase marked as link) to e.g. a talk page, we will drop tokens that should have not been dropped.
    # The correct way would be to distinguish links to categories and interwiki from the rest and to treat them separately.
    # However, it is not easy (every language has its own term for "Category") and links from the main namespace to the other namespaces will be very rare.
    $wiki =~ s/\[\[[-A-Za-z ]+:$nobracket+\]\]//gs;
    # Replace links by their visible text.
    $wiki =~ s/\[\[$nobracketpipe*\|($nobracketpipe*)\]\]/$1/gs;
    $wiki =~ s/\[\[($nobracketpipe*)\]\]/$1/gs;
    my $url = 'https?://[-A-Za-z0-9_./~+%?=&#]+';
    $wiki =~ s/\[$url\s+(.*?)\]/$1/gs;
    # Remove bold and italics formatting.
    $wiki =~ s/'''(.+?)'''/$1/gs;
    $wiki =~ s/''(.+?)''/$1/gs;
    # Remove references. Empty elements (<ref/>) first, so that they do not interfer when removing paired tags (<ref>...</ref>).
    $wiki =~ s:<ref( .*?)??/>::igs;
    $wiki =~ s:<ref( .*?)??>.*?</ref>::igs;
    # Remove nowiki escapes (###!!! but we should have taken them into account above!)
    # Also remove other easy markup.
    $wiki =~ s:</?(nowiki|center)>::igs;
    return $wiki;
}



#------------------------------------------------------------------------------
# Removes nested constructs of MediaWiki syntax. Example:
# $wiki = $self->remove_nested($wiki, '\{\{', '\}\}', '{}');
#------------------------------------------------------------------------------
sub remove_nested
{
    my $self = shift;
    my $wiki = shift;
    my $ini = shift; # initial bracketing string
    my $fin = shift; # final bracketing string
    my $noinside = shift; # characters that must not be inside
    my $inside = defined($noinside) ? "[^$noinside]" : '.';
    while($wiki =~ s/$ini$inside*$fin//gs) {}
    return $wiki;
}



#------------------------------------------------------------------------------
# Removes superfluous empty lines. Empty lines serve as paragraph separators.
# This method ensures that there are no leading and trailing empty lines, that
# there are never two or more consequent empty lines and that there is always
# just one non-empty line between two empty ones (i.e. no line breaks within
# a paragraph).
#------------------------------------------------------------------------------
sub normalize_line_breaks
{
    my $self = shift;
    my $wiki = shift;
    my @lines = split(/\n/, $wiki);
    for(my $i = 0; $i>=0 && $i<=$#lines; $i++)
    {
        my $ok = 1;
        my $empty = $lines[$i] =~ m/^\s*$/;
        my $prevempty = $i==0 || $lines[$i-1] =~ m/^\s*$/;
        # The first line must not be empty.
        if($i==0 && $empty)
        {
            splice(@lines, $i, 1);
            $i--;
            $ok = 0;
        }
        # The last line must not be empty.
        elsif($i==$#lines && $empty)
        {
            splice(@lines, $i, 1);
            $i -= 2;
            $ok = 0;
        }
        # Two consequent lines must not be empty.
        elsif($prevempty && $empty)
        {
            splice(@lines, $i, 1);
            $i--;
            $ok = 0;
        }
        # A paragraph must not span multiple lines.
        elsif(!$prevempty && !$empty)
        {
            $lines[$i-1] .= ' '.$lines[$i];
            splice(@lines, $i, 1);
            $i--;
            $ok = 0;
        }
        # If we did not remove the current line let's normalize spaces within it.
        if($ok)
        {
            $lines[$i] =~ s/^\s+//;
            $lines[$i] =~ s/\s+$//;
            $lines[$i] =~ s/\s+/ /g;
        }
    }
    $wiki = join("\n", @lines)."\n";
    return $wiki;
}



1;

__END__

=head1 NAME

Treex::Block::Read::WikiDump

=head1 DESCRIPTION

Reads dumps of Wikipedia articles in XML format. Example file:
C<http://dumps.wikimedia.org/trwiki/20130606/trwiki-20130606-pages-articles.xml.bz2>

Only the contents of the XML elements <text> will be read.
The rest will be ignored.
Every page's text will be read into a separate document.
MediaWiki syntax will be discarded so that only plain text remains.
Templates will be discarded too, they will not be expanded.

The text is stored to the L<document|Treex::Core::Document>'s attribute C<text>.
Neither tokenization nor sentence segmentation is performed.

Note that the input dumpfile can be gzipped (as can any input to Treex)
but it cannot be bzipped2 (which is the default compression provided by Wikipedia).

=head1 EXAMPLE USAGE

Beware: Treex will create one text file per Wikipedia article.
This could mean hundreds of thousands of files in one folder,
which would drastically slow down certain operations in that folder.
It is also not possible to refer to the files using shell wildcards
(C<*.txt>) because the maximal length of the commandline will be
exceeded.

 DUMP=trwiki-20130606-pages-articles
 wget http://dumps.wikimedia.org/trwiki/20130606/$DUMP.xml.bz2
 bunzip2 $DUMP.xml.bz2
 gzip $DUMP.xml
 treex -Ltr Read::WikiDump from=$DUMP.xml.gz Write::Text path=texts to=.
 # Note that zip has problems with UTF8 characters in filenames.
 find texts -name '*.txt' -print | zip -m trwiki -@

 find texts -name '*.txt' -print > filelist.txt
 tar czf trwiki.tgz --files-from filelist.txt

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

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
