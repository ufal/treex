package Treex::Core::DocumentReader::Base;

use Moose;
use Treex::Core::Common;
with 'Treex::Core::DocumentReader';

has encoding => ( isa => 'Str', is => 'ro', default => 'utf8' );

has selector => ( isa => 'Treex::Type::Selector', is => 'ro', default => '' );

has file_stem => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'how to name the loaded documents',
);

has lines_per_doc => ( isa => 'Int',  is => 'ro', default => 0 );
has merge_files   => ( isa => 'Bool', is => 'ro', default => 0 );

has check_same_number_of_files_per_zone => (
    isa           => 'Bool',
    is            => 'ro',
    default       => 1,
    documentation => 'exit with fatal error if zones have different number of input files',
);

has save_doc_text => (
    isa           => 'Bool',
    is            => 'ro',
    default       => 0,
    documentation => 'save raw document text into (each) doc-zone "text" attribute',
);

has _files_per_zone => ( is => 'rw', default => 0 );

has zones => (
    isa     => 'ArrayRef[Treex::Core::DocumentReader::ZoneReader]',
    is      => 'ro',
    default => sub { [] },
);

has is_one_doc_per_file => (
    is      => 'ro',
    isa     => 'Bool',
    default => 1,
);

sub BUILD {
    my ( $self, $args ) = @_;
    foreach my $arg ( keys %{$args} ) {
        my ( $lang, $sele ) = ( $arg, '' );
        if ( $arg =~ /_/ ) {
            ( $lang, $sele ) = split /_/, $arg;
        }
        if ( Treex::Core::Types::is_lang_code($lang) ) {
            $self->add_zone_files( $lang, $sele, $args->{$arg} );
        }
        elsif ( $arg =~ /selector|language|scenario/ ) { }
        else {
            log_warn "$arg is not a zone label (e.g. en_src)";
        }
    }
    return;
}

sub add_zone_filenames {
    my ( $self, $language, $selector, $files_string ) = @_;
    $files_string =~ s/^\s+|\s+$//g;
    my @files = split( /[ ,]+/, $files_string );

    if ( $self->check_same_number_of_files_per_zone ) {
        if ( !$self->_files_per_zone ) {
            $self->_set_files_per_zone( scalar @files );
        }
        elsif ( @files != $self->_files_per_zone ) {
            log_fatal("All zones must have the same number of files");
        }
    }

    push @{ $self->zones }, Treex::Core::DocumentReader::ReaderZone->new(
        language      => $language,
        selector      => $selector,
        filenames     => \@files,
        encoding      => $self->encoding,
        lines_per_doc => $self->lines_per_doc,
        merge_files   => $self->merge_files,
    );
    return;
}

sub new_document {
    my ( $self, $load_from ) = @_;
    my ( $stem, $file_number ) = ( '', '' );
    my ( $volume, $dirs, $file );
    if ( $self->file_stem ) {
        ( $stem, $file_number ) = ( $self->file_stem, undef );
    }
    else {    # Magical heuristics how to choose default name for a document loaded from several files
        foreach my $zone ( @{ $self->zones } ) {
            my $filename = $zone->current_filename;
            ( $volume, $dirs, $file ) = File::Spec->splitpath($filename);
            my ( $name ) = $file =~ /([^.]+)(\..+)?/;
            my $zonelabel = $zone->zone_label;
            my $lang      = $zone->language;
            my $sele      = $zone->selector;
            $name =~ s/[_-]?($lang|$sele|$zonelabel)[_-]?//gi;
            if ( !$name && !$stem ) {
                $name        = 'noname';
                $file_number = undef;
            }
            if ( $stem !~ /$name/ ) {
                if ( $stem ne '' ) {
                    $stem .= '_';
                }
                $stem .= $name;
            }
        }
    }

    $self->_set_doc_number( $self->doc_number + 1 );
    return Treex::Core::Document->new(
        {
            file_stem => $stem,
            loaded_from => join( ',', map { $_->current_filename } @{ $self->zones } ),
            defined $file_number ? ( file_number => $file_number )    : (),
            defined $dirs        ? ( path        => $volume . $dirs ) : (),
            defined $load_from   ? ( filename    => $load_from )      : (),
        }
    );
}

sub number_of_documents {
    my $self = shift;
    return if !$self->is_one_doc_per_file;
    return $self->_files_per_zone;
}

after 'restart' => sub {
    my $self = shift;
    foreach my $zone_reader ( values %{ $self->zones } ) {
        $zone_reader->reset();
    }
    return;
};

sub zonelabels {
    my ($self) = @_;
    return map { $_->zone_label } @{ $self->zones };
}

sub next_document {
    my ($self) = @_;
    my ( %texts, %sents, $n_sentences );

    foreach my $zone ( @{ $self->zones } ) {
        my $text      = $zone->next_document_text();
        my $zonelabel = $zone->zonelabel;
        $texts{$zonelabel} = $text;
    }
    my $doc = $self->new_document();

    if ( $self->save_doc_text ) {
        foreach my $zone ( @{ $self->zones } ) {
            my $zonelabel = $zone->zonelabel;
            my $language  = $zone->language;
            my $selector  = $zone->selector;
            my $doczone   = $doc->create_zone( $language, $selector );
            $doczone->set_text( $texts{$zonelabel} );
        }
    }

    my $same_n_sentences = 1;
    foreach my $zonelabel ( $self->zonelabels ) {
        my $text = $texts{$zonelabel};
        my @sentences = $self->get_sentences_from_doc_text( $text, $zonelabel );
        $sents{$zonelabel} = \@sentences;
        if ( !defined $n_sentences ) {
            $n_sentences = @sentences;
        }
        elsif ( $n_sentences != @sentences ) {
            $same_n_sentences = 0;
        }
    }

    if ( !$same_n_sentences ) {
        log_fatal 'Different number of sentences for each zone: '
            . join( ', ', map { "$_=" . scalar( @{ $sents{$_} } ) } $self->zonelabels );
    }

    for my $i ( 1 .. $n_sentences ) {
        my $bundle = $doc->create_bundle();

        foreach my $zonelabel ( $self->zonelabels ) {
            my ( $language, $selector ) = ( $zonelabel, '' );
            if ( $zonelabel =~ /_/ ) {
                ( $language, $selector ) = split /_/, $zonelabel;
            }
            my $zone = $bundle->create_zone( $language, $selector );
            $self->fill_bundle_zone( $zone, $sents{$zonelabel}[ $i - 1 ] );
        }
    }

    return $doc;
}

sub get_sentences_from_doc_text {
    my ( $self, $doc_text, $zone_label ) = @_;
    return split /\n/, $doc_text;
}

sub fill_bundle_zone {
    my ( $self, $zone, $raw_sentence ) = @_;
    return log_fatal 'fill_bundle_zone must be overriden';
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Core::DocumentReader::Base - base implementation of document readers

=head1 DESCRIPTION

Base implementation of L<Treex::Core::DocumentReader>.
Experimental code, not used so far.

=head1 METHODS

TODO

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
