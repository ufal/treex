package Treex::Block::Read::CdtPack;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::CdtTag'; # just to inherit insert_nodes_from_tag()

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
            $self->_file_list->{$number}{tag}{$language}{$file_to_process} = 1;
        }

        elsif ($file_to_process =~ /\.atag$/ ) {
            if (not $file_to_process =~ /-da-(..)[.\-]/) {
                log_fatal "Language code cannot be detected from file name: $file_to_process";
            }
            my $language = $1;
            $self->_file_list->{$number}{atag}{$file_to_process} = 1;
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

    my $document = Treex::Core::Document->new;
    my $bundle = $document->create_bundle;

    foreach my $language (sort keys %{$self->_file_list->{$number}{tag}}) {
        my $zone = $bundle->create_zone($language);
        my $atree = $zone->create_atree;
        my ($filename) = keys %{$self->_file_list->{$number}{tag}{$language}};
        $self->insert_nodes_from_tag( $atree, $filename );
    }

    $document->set_file_stem("cdt$number");
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
