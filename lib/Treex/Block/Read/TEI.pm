package Treex::Block::Read::TEI;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseReader';
use Moose::Util qw(apply_all_roles);
use XML::Twig;

has language        => ( isa => 'Treex::Type::LangCode', is => 'ro', required => 1 );
has bundles_per_doc => ( isa => 'Int', is => 'ro', default => 0 );
has _twig           => ( isa => 'XML::Twig', is => 'ro', writer => '_set_twig' );
has _buffer         => ( isa => 'ArrayRef', is => 'ro', default => sub { [] } );



sub BUILD
{
    my ($self) = @_;
    if ( $self->bundles_per_doc )
    {
        $self->set_is_one_doc_per_file(0);
    }
    $self->_set_twig( XML::Twig::->new() );
    return;
}



#------------------------------------------------------------------------------
# Converts a XML Twig <s> element to a bundle in the current Treex document.
#------------------------------------------------------------------------------
sub process_sentence
{
    my $self = shift;
    my $document = shift; # current Treex document
    my $sentence = shift; # twig from the input XML
    my $bundle = $document->create_bundle();
    $bundle->set_id($sentence->{att}{'xml:id'});
    my $zone = $bundle->create_zone( $self->language(), $self->selector() );
    my $root = $zone->create_atree();
    $root->set_id($bundle->id().'.t0');
    # Inside the sentence:
    # <w>...</w> is a word
    # <c>...</c> is a punctuation symbol
    # <S /> is space
    # <links>...</links> is a special section defining the dependency arcs.
    my @nodes;
    my %nodes_by_id;
    my $ord = 0;
    my $space = 0;
    my $sentence_text = '';
    foreach my $element ($sentence->descendants(qr/^[wcS]$/))
    {
        if ($element->tag() eq 'S')
        {
            $space = 1;
            $sentence_text .= ' ';
        }
        else
        {
            # If this is not the first token of the sentence and if there was no space
            # between this and the previous token, set flag at the previous token that
            # there is no space after it.
            if($ord > 0)
            {
                if(!$space)
                {
                    $nodes[-1]->set_no_space_after(1);
                }
                $space = 0;
            }
            $ord++;
            my $node = $root->create_child();
            $node->set_id($element->{att}{'xml:id'});
            $node->_set_ord($ord);
            $node->set_form($element->field());
            $sentence_text .= $node->form();
            if ($element->tag() eq 'w')
            {
                $node->set_lemma($element->{att}{lemma});
                $node->set_tag($element->{att}{msd});
                $node->set_deprel('root');
            }
            else # <c>
            {
                $node->set_lemma($element->field());
                $node->set_tag('PUNCT');
                $node->set_deprel('punct');
            }
            push(@nodes, $node);
            $nodes_by_id{$node->id()} = $node;
        }
    }
    $zone->set_sentence($sentence_text);
    # The <links> element describes dependencies between tokens.
    foreach my $element ($sentence->descendants('link'))
    {
        my $parent_id = $element->{att}{from};
        my $child_id = $element->{att}{dep};
        my $relation = $element->{att}{afun};
        # If $parent_id ends with '.t0', it is the root.
        # We do not have the root in the hash but all children are initially attachet to the root
        # so we do not need to do anything.
        if($parent_id =~ m/\.t0$/)
        {
            # Do nothing.
        }
        elsif(exists($nodes_by_id{$parent_id}) && exists($nodes_by_id{$child_id}))
        {
            my $parent = $nodes_by_id{$parent_id};
            my $child = $nodes_by_id{$child_id};
            $child->set_parent($parent);
            $child->set_deprel($relation);
        }
        else
        {
            log_warn("Cannot create dependency $parent_id --- $relation ---> $child_id");
        }
    }
}



#------------------------------------------------------------------------------
# Reads the a XML file, parses its contents and converts sentence elements to
# bundles in the current Treex document. If we have a limit on number of
# sentences per document and if the input XML contains more sentences, the
# remaining <s> elements are stored in a buffer so they can be processed later
# and added to another Treex document. This can still exhaust the memory if the
# input XML file is huge. There is no way of interrupting parsing the XML file,
# returning from the next_document() method of this block, then resume the XML
# parsing later from the same position. (Actually, there is one option, but it
# comes for the price of speed: When we get back to this block to read the next
# batch of sentences, the whole XML will be parsed from the beginning again,
# and the sentences that have been processed earlier will be skipped.)
#------------------------------------------------------------------------------
sub parse_xml_file
{
    my $self = shift;
    my $filename = shift;
    my $document = shift;
    my $bpd = $self->bundles_per_doc();
    my $n_sent_doc = 0;
    # Define what the Twig XML parser does with particular XML elements.
    $self->_twig()->setTwigRoots
    ({
        's' => sub
        {
            my $twig = shift;
            my $sentence = shift;
            # <s>...</s> is a sentence
            # Delete all elements that have been completely parsed so far.
            $twig->purge();
            $n_sent_doc++;
            if ($bpd && $n_sent_doc > $bpd)
            {
                my $buffer = $self->_buffer();
                push(@{$buffer}, $sentence);
            }
            else
            {
                $self->process_sentence($document, $sentence);
            }
            # Tell the parser that subsequent handlers shall also be called.
            return 1;
        }
    });
    # The parser is ready, now parse the file.
    $self->_twig->parsefile($filename);
}



#------------------------------------------------------------------------------
# Processes sentences from the buffer.
#------------------------------------------------------------------------------
sub process_buffer
{
    my $self = shift;
    my $document = shift;
    my $buffer = $self->_buffer();
    my $bpd = $self->bundles_per_doc();
    my $n_sent_doc = 0;
    while (1)
    {
        $n_sent_doc++;
        if ($bpd && $n_sent_doc > $bpd)
        {
            last;
        }
        else
        {
            my $sentence = shift(@{$buffer});
            last if(!defined($sentence));
            $self->process_sentence($document, $sentence);
        }
    }
}



#------------------------------------------------------------------------------
# Reads the next XML file, parses its contents and stores it in the Treex data
# structures.
#------------------------------------------------------------------------------
sub next_document
{
    my $self = shift;
    my $document;
    # If there is anything in the buffer from the previous calls, process it.
    # Do not proceed to the next file even if there are not enough sentences in the buffer.
    # The next file will start a new document in any case.
    my $buffer = $self->_buffer();
    if(scalar(@{$buffer}) > 0)
    {
        $document = $self->new_document();
        $self->process_buffer($document);
    }
    else
    {
        my $filename = $self->next_filename();
        return if(!defined($filename));
        log_info("Loading $filename...");
        $document = $self->new_document();
        $self->parse_xml_file($filename, $document);
    }
    return $document;
}



1;

__END__

=head1 NAME

Treex::Block::Read::TEI

=head1 DESCRIPTION

Document reader for the XML-based TEI (Text Encoding Initiative) family of
formats. It is used to store the Slovene reference treebank.

=head1 METHODS

=over

=item next_document

Loads a document.

=back

=head1 PARAMETERS

=over

none

=head1 SEE

L<Treex::Block::Read::BaseReader>

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
