package Treex::Block::Read::CnecXML;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseTextReader';
use XML::Twig;

has _twig => (
    isa    => 'XML::Twig',
    is     => 'ro',
    writer => '_set_twig',
);

sub BUILD {
    my ($self) = @_;
    $self->_set_twig( XML::Twig::->new() );
    return;
}


sub next_document {
    my ($self) = @_;
    my $text = $self->next_document_text();
    return if !defined $text;
    my $twig = $self->_twig;

    my $document = $self->new_document();
    foreach my $sentence_xml ( split /\n/, $text ) {
        $sentence_xml =~ s{</?doc>}{};
        next if $sentence_xml eq '';

        my $bundle = $document->create_bundle();
        my $zone = $bundle->create_zone( $self->language, $self->selector );
        my $atree = $zone->create_atree();
        my $ntree = $zone->create_ntree();
        my $ord = 1;
        $twig->parse("<dummy>$sentence_xml</dummy>");
        foreach my $element ($twig->root->children){
            my $tag = $element->tag;
            my @forms = split / /, $element->trimmed_text;
            my @anodes = map {$atree->create_child({form=>$_, ord=>$ord++})} @forms;
            if ($tag eq '#PCDATA'){}
            elsif ($tag eq 'ne'){
                my $nnode = $ntree->create_child({ne_type=>$element->{att}{type}, normalized_name=>$element->{att}{normalized_name}});
                $nnode->set_anodes(@anodes);
            }
            else {
                log_warn("Ignoring unknown tag '$tag' in '$sentence_xml'");
            }
        }
        $zone->set_sentence(join ' ', map {$_->form} $atree->get_children());
    }

    return $document;
}



1;

__END__

=head1 NAME

Treex::Block::Read::CnecXML

=head1 DESCRIPTION

Document reader for CNEC (Czech Named Entity Corpus) 2.0 XML format:

 <doc>
 Vede ji žena , jmenuje se <ne type="P" normalized_name="Ann Suba">Ann Suba</ne> .
 </doc>

There is one sentence per line.
The attribute C<normalized_name> is not present in the original CNEC data.

TODO:
The reader does not support nested named entities, so far.

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
