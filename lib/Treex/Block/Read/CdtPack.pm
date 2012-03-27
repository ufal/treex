package Treex::Block::Read::CdtPack;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::CdtTag'; # just to inherit insert_nodes_from_tag()

use Treex::Tool::CopenhagenDT::XmlizeTagFormat;

has _file_list => ( # 4-level hash $_file_lists->{$number}{$format}{$language}{$filename}
    is => 'rw',
    isa => 'HashRef',
);

has _unprocessed_numbers => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub {[]},
);

sub _initialize_file_lists {
    my $self = shift;

    while ( <STDIN> ) {
        chomp;
        my $file_to_process = $_;
        my $number;
        if ( $file_to_process =~ /(\d{4})/ ) {
            $number = $1;
        }
        else {
            log_fatal "File name for CdtPack conversion must contain a four-digit number, this doesn't: $file_to_process";
        }

        if (not defined $self->_file_list ) {
            $self->_set_file_list({});
        }

        if ( $file_to_process =~ /\.tag$/ ) {
            if (not $file_to_process =~ /-(..)[.\-]/) {
                log_fatal "Language code cannot be detected from file name: $file_to_process";
            }
            my $language = $1;
            $self->_file_list->{$number}{tag}{$language} = $file_to_process;
        }

        elsif ($file_to_process =~ /\.atag$/ ) {
            if (not $file_to_process =~ /-da-(..)[.\-]/) {
                log_fatal "Language code cannot be detected from file name: $file_to_process";
            }
            my $language = $1;
            $self->_file_list->{$number}{atag}{$language} = $file_to_process;
        }

        else {
            log_fatal "Allowed extensions for CdtPack are only .tag and .atag.. File: $file_to_process";
        }
    }

    foreach my $number (reverse sort keys %{$self->_file_list}) {
        push @{$self->_unprocessed_numbers}, $number;
    }
}




sub next_document {
    my ($self) = @_;

    if (not defined $self->_file_list) {
        $self->_initialize_file_lists();
    }

    my $number = pop @{$self->_unprocessed_numbers};

    return if not defined $number;
#    print "NUMBER: $number\n";

    my $document = Treex::Core::Document->new;
    my $bundle = $document->create_bundle;

    foreach my $language (sort keys %{$self->_file_list->{$number}{tag}}) {
        my $zone = $bundle->create_zone($language);
        my $atree = $zone->create_atree;
        my $filename = $self->_file_list->{$number}{tag}{$language};
        $self->insert_nodes_from_tag( $atree, $filename );
    }

    foreach my $aligned_language ( keys %{$self->_file_list->{$number}{atag}}) {

        $bundle->wild->{$aligned_language} = [];

        my $atag_document = XML::Twig->new();

        my $filename = $self->_file_list->{$number}{atag}{$aligned_language};
        my $xml_content = Treex::Tool::CopenhagenDT::XmlizeTagFormat::read_and_xmlize($filename);

        if (not eval { $atag_document->parse( $xml_content ) }) {
            $self->dump_xmlized_file($filename,$xml_content);
        }

        foreach my $align_element ($atag_document->descendants('align')) {
            my %attr_hash = ();
            foreach my $attr_name (keys %{$align_element->{'att'}||{}}) {
                $attr_hash{$attr_name} = $align_element->{'att'}->{$attr_name};
            }
            push @{$bundle->wild->{$aligned_language}}, \%attr_hash;
        }
    }

    # determine file name according to available annotations
    my $code;
    foreach my $language (qw(de es it)) {
        $code .= "-$language";
        if (defined $self->_file_list->{$number}{tag}{$language}) {
            if ($self->_file_list->{$number}{tag}{$language} =~ /tagged/) {
                $code .= 1; # only automatically tokenized
            }
            else {
                $code .= 2; # manually annotated
            }

            if (defined $self->_file_list->{$number}{atag}{$language}) {
                $code .= 1; # alignment available
            }
            else {
                $code .= 0; # alignment unavailable
            }
        }
        else {
            $code .= '00'; #language not present at all
        }
    }


    $document->set_file_stem("cdt$number$code");
    $document->set_file_number("");

    return $document;
}


1;





__END__



=head1 NAME

Treex::Block::Read::CdtPack

=head1 DESCRIPTION

Read a list of Copenhagen Dependency Treebank files in tag format (morphology+syntax)
and atag format (alignment), cluster the files according to their 4-digit prefix
and create one treex file for each such cluster.

=head1 AUTHOR

Zdeněk Žabokrtský

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
