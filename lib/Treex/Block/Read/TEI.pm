package Treex::Block::Read::TEI;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseReader';
use Moose::Util qw(apply_all_roles);
use XML::Twig;

has bundles_per_doc => (
    is      => 'ro',
    isa     => 'Int',
    default => 0,
);

has language => ( isa => 'Treex::Type::LangCode', is => 'ro', required => 1 );

has _twig => (
    isa    => 'XML::Twig',
    is     => 'ro',
    writer => '_set_twig',
);



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
# Reads the next XML file, parses its contents and stores it in the Treex data
# structures.
#------------------------------------------------------------------------------
sub next_document
{
    my ($self) = @_;
    my $filename = $self->next_filename();
    return if !defined $filename;
    log_info "Loading $filename...";
    my $document = $self->new_document();
    my $n_sent_doc = 0;
    # Define what the Twig XML parser does with particular XML elements.
    $self->_twig->setTwigRoots
    ({
        s => sub
        {
            $n_sent_doc++;
            if ($self->bundles_per_doc() && $n_sent_doc > $self->bundles_per_doc())
            {
                ###!!! TODO: Find out how to stop processing of one document and later restart at the same position.
                ###!!! For now, we just skip the rest of the document!
                return;
            }
            # <s>...</s> is a sentence
            my ( $twig, $sentence ) = @_;
            # Delete all elements that have been completely parsed so far.
            $twig->purge();
            my $bundle = $document->create_bundle();
            my $zone   = $bundle->create_zone( $self->language(), $self->selector() );
            my $root   = $zone->create_atree();
            # Inside the sentence:
            # <w>...</w> is a word
            # <c>...</c> is a punctuation symbol
            # <S /> is space
            # <links>...</links> is a special section defining the dependency arcs.
            my @nodes;
            my $ord = 0;
            foreach my $element ($sentence->descendants(qr/^[wc]$/))
            {
                $ord++;
                my $node = $root->create_child();
                $node->set_id($element->{att}{'xml:id'});
                $node->_set_ord($ord);
                $node->set_form($element->field());
                if ($element->tag() eq 'w')
                {
                    $node->set_lemma($element->{att}{lemma});
                    $node->set_tag($element->{att}{msd});
                }
                else # <c>
                {
                    $node->set_lemma($element->field());
                    $node->set_tag('PUNCT');
                }
                ###!!! TODO: We should also read the <S /> elements (spaces between tokens)
                ###!!! and $node->set_nospaceafter() accordingly.
                push(@nodes, $node);
            }
            ###!!! TODO: We should also read the <links> section and add the dependencies.
            # Assume that the nodes appear in the original word order of the sentence.
            # Set the sentence attribute of the zone.
            my $sentence_text = join(' ', map {$_->form()} @nodes); ###!!! TODO: take nospaceafter into account
            $zone->set_sentence($sentence_text);
        }
    });
    # The parser is ready, now parse the file.
    $self->_twig->parsefile($filename);
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
