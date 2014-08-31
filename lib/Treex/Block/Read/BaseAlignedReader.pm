package Treex::Block::Read::BaseAlignedReader;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
with 'Treex::Core::DocumentReader';
use Treex::Core::Document;

sub next_document {
    my ($self) = @_;
    return log_fatal "method next_document must be overriden in " . ref($self);
}

has selector => ( isa => 'Treex::Type::Selector', is => 'ro', default => '' );

has file_stem => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'how to name the loaded documents',
);

# private attributes
has _filenames => (
    isa           => 'HashRef[Str]',
    is            => 'rw',
    init_arg      => undef,
    default       => sub { {} },
    documentation => 'mapping zone_label->filenames to be loaded;'
        . ' automatically initialized from constructor arguments',
);

has _files_per_zone => ( is => 'rw', default => 0 );

has _file_number => (
    isa           => 'Int',
    is            => 'rw',
    default       => 0,
    init_arg      => undef,
    documentation => 'Number of n-tuples of input files loaded so far.',
);

#BUILD is needed for processing generic arguments - now only shortcuts of type langcode_selector
sub BUILD {
    my ( $self, $args ) = @_;
    foreach my $arg ( keys %{$args} ) {
        my ( $lang, $sele ) = ( $arg, '' );
        if ( $arg =~ /_/ ) {
            ( $lang, $sele ) = split /_/, $arg;
        }
        if ( is_lang_code($lang) ) {
            my $files = Treex::Core::Files->new({string => $args->{$arg}});
            if ( !$self->_files_per_zone ) {
                $self->_set_files_per_zone( $files->number_of_files );
            }
            elsif ( $files->number_of_files != $self->_files_per_zone ) {
                log_fatal('All zones must have the same number of files: ' . $files->number_of_files . ' != ' . $self->_files_per_zone);
            }
            $self->_filenames->{$arg} = $files;
        }
        elsif ( $arg =~ /selector|language|scenario/ ) { }
        else                                           { log_warn "$arg is not a zone label (e.g. en_src)"; }
    }
    return;
}

sub current_filenames {
    my ($self) = @_;
    my $n = $self->_file_number;
    return if $n == 0 || $n > $self->_files_per_zone;
    my %result = map { $_ => $self->_filenames->{$_}->filenames->[ $n - 1 ] } keys %{ $self->_filenames };
    return \%result;
}

sub next_filenames {
    my ($self) = @_;
    $self->_set_file_number( $self->_file_number + 1 );
    return $self->current_filenames;
}

sub new_document {
    my ( $self, $load_from ) = @_;
    my %filenames = %{$self->current_filenames()};
    log_fatal "next_filenames() must be called before new_document()" if !%filenames;

    my ( $stem, $file_number ) = ( '', '' );
    my ( $volume, $dirs, $file );
    if ( $self->file_stem ) {
        ( $stem, $file_number ) = ( $self->file_stem, undef );
    }
    else {    # Magical heuristics how to choose default name for a document loaded from several files
        foreach my $zone_label ( keys %filenames ) {
            my $filename = $filenames{$zone_label};
            ( $volume, $dirs, $file ) = File::Spec->splitpath($filename);

            # Delete file extension, e.g.
            # file.01.conll -> file.01
            # cs42.treex.gz -> cs42
            $file =~ s/\.[^.]+(\.gz)?$//;

            # Substitute standard input for noname.
            $file =~ s/^-$/noname/;

            # Heuristically delete indication of language&selector from the filename.
            my ( $lang, $sele ) = ( $zone_label, '' );
            if ( $zone_label =~ /_/ ) {
                ( $lang, $sele ) = split /_/, $zone_label;
            }
            $file =~ s/[_-]?($lang|$sele|$zone_label)[_-]?//gi;
            if ( !$file && !$stem ) {
                $file        = 'noname';
                $file_number = undef;
            }
            if ( $stem !~ /$file/ ) {
                if ( $stem ne '' ) {
                    $stem .= '_';
                }
                $stem .= $file;
            }
        }
    }

    $self->_set_doc_number( $self->doc_number + 1 );
    return Treex::Core::Document->new(
        {
            file_stem => $stem,
            loaded_from => join( ',', values %filenames ),
            defined $file_number ? ( file_number => $file_number )    : (),
            defined $dirs        ? ( path        => $volume . $dirs ) : (),
            defined $load_from   ? ( filename    => $load_from )      : (),
        }
    );
}

sub number_of_documents {
    my $self = shift;
    return $self->_files_per_zone;
}

after 'restart' => sub {
    my $self = shift;
    $self->_set_file_number(0);
};

1;

__END__

=for Pod::Coverage BUILD

=head1 NAME

Treex::Block::Read::BaseAlignedReader - abstract ancestor for parallel-corpora document readers

=head1 SYNOPSIS

  # in scenarios
  Read::MyAlignedFormat en=english.txt de=german.txt

  # Zones can differ also in selectors, any number of zones can be read
  Read::MyAlignedFormat en_ref=ref1,ref2 en_moses=mos1,mos2 en_tectomt=tmt1,tmt2

=head1 DESCRIPTION

This class serves as a common ancestor for document readers
that read more zones at once -- usually parallel sentences in two (or more) languages.
The readers take parameters named as the zones and values of the parameters
is a space or comma separated list of filenames to be loaded into the given zone.
The class is designed to implement the L<Treex::Core::DocumentReader> interface.

In derived classes you need to define the C<next_document> method,
and you can use C<next_filenames> and C<new_document> methods.

=head1 ATTRIBUTES

=over

=item any parameter in a form of a valid I<zone_label>

space or comma separated list of filenames, or C<-> for STDIN.

=item file_stem (optional)

How to name the loaded documents.
This attribute will be saved to the same-named
attribute in documents and it will be used in document writers
to decide where to save the files.

=back

=head1 METHODS

=over

=item next_document

This method must be overriden in derived classes.
(The implementation in this class just issues fatal error.)

=item next_filenames

Returns a hashref of filenames (full paths) to be loaded.
The keys of the hash are zone labels, the values are the filenames.

=item new_document($load_from?)

Returns a new empty document with pre-filled attributes
C<loaded_from>, C<file_stem>, C<file_number> and C<path>
which are guessed based on C<current_filenames>.

=item current_filenames

returns the last filenames returned by C<next_filenames>

=item number_of_documents

Returns the number of documents that will be read by this reader.

=back

=head1 SEE ALSO

L<Treex::Block::Read::BaseReader>
L<Treex::Block::Read::BaseAlignedTextReader>

=head1 AUTHOR

Martin Popel

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

