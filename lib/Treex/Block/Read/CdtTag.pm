package Treex::Block::Read::CdtTag;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BaseReader';
with 'Treex::Block::Read::BaseSplitterRole';

use XML::Twig;

use Treex::Tool::CopenhagenDT::XmlizeTagFormat;

sub next_document {
    my ($self) = @_;

    my $filename = $self->next_filename();

    return if not defined $filename;

    my $language;
    if ($filename =~ /-([a-z]{2})[.-]/) {
        $language = $1;
    }
    else {
        log_fatal "Can't detect language code in the file name: $filename";
    }

    my $document = $self->new_document;
    my $bundle = $document->create_bundle;
    my $zone = $bundle->create_zone($language);
    my $atree = $zone->create_atree;

    insert_nodes_from_tag( $self, $atree, $filename );

    return $document;
}


sub insert_nodes_from_tag {
    my ( $self, $atree, $filename ) = @_;

    my $xml_content = Treex::Tool::CopenhagenDT::XmlizeTagFormat::read_and_xmlize($filename);

    # add token numbering first, as it is used for references
    my $numbered_xml_content;
    my $line_number = 0;
    foreach my $line (split /\n/,$xml_content) {
        $line =~ s/<W /<W linenumber="$line_number" /;
        $numbered_xml_content .= $line."\n";
        $line_number++;
    }

    # read the XML structure
    my $tag_document = XML::Twig->new();
    if (not eval { $tag_document->parse( $numbered_xml_content ) } ) {
        $self->dump_xmlized_file($filename,$numbered_xml_content);
    }

    # remember which tokens belonged to which sentence or paragraph (<s> and <p> tags, if present)
    my %sent_number;
    my %para_number;

    my $para_counter = 0;
    foreach my $para ($tag_document->descendants('p')) {
        $para_counter++;
        foreach my $tag_token ($para->descendants('W')) {
            $para_number{$tag_token} = $para_counter;
        }
    }

    my $sent_counter = 0;
    foreach my $sent ($tag_document->descendants('s')) {
        $sent_counter++;
        foreach my $tag_token ($sent->descendants('W')) {
            $sent_number{$tag_token} = $sent_counter;
        }
    }

    # build a flat tree from the tokens
    my $ord = 0;
    foreach my $tag_token ($tag_document->descendants('W')) {
        $ord++;
        my $anode = $atree->create_child(
            {
                form => $tag_token->text,
                ord => $ord,
            }
        );
        foreach my $attr_name (keys %{$tag_token->{'att'}||{}}) {
            $anode->wild->{$attr_name} = $tag_token->{'att'}->{$attr_name};
        }
        $anode->wild->{para_number} = $para_number{$tag_token} || 0;
        $anode->wild->{sent_number} = $sent_number{$tag_token} || 0;
    }
}

sub dump_xmlized_file {
    my ( $self, $filename, $xml_content ) = @_;

    my $dump_filename = $filename;
    $dump_filename =~ s/.*\///;
    $dump_filename = "dump-$dump_filename.xml";

    open my $WRONG_XML,">:utf8",$dump_filename;
    print $WRONG_XML $xml_content;
    close $WRONG_XML;

    log_warn "Partially fixed, but still unparsable XML content stored to $dump_filename\n";
}

1;

__END__

=head1 NAME

Treex::Block::Read::CdtTag

=head1 DESCRIPTION

Document reader for *.tag files used in the Copenhagen Dependency Treebank
and associated projects. The tag format is a semi-XML line-oriented format.

=head1 AUTHOR

Zdeněk Žabokrtský

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
