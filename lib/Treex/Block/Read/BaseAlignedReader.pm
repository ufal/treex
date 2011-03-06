package Treex::Block::Read::BaseAlignedReader;
use Moose;
use Treex::Moose;
with 'Treex::Core::DocumentReader';

sub next_document {
    my ($self) = @_;
    return log_fatal "method next_document must be overriden in " . ref($self);
}

has selector => ( isa => 'Selector', is => 'ro', default => '' );

has file_stem => (
    isa           => 'Str',
    is            => 'ro',
    documentation => 'how to name the loaded documents',
);

# private attributes
has _filenames => (
    isa           => 'HashRef[LangCode]',
    is            => 'ro',
    init_arg      => undef,
    default       => sub { {} },
    documentation => 'mapping language->filenames to be loaded;'
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

sub BUILD {
    my ( $self, $args ) = @_;
    foreach my $arg ( keys %{$args} ) {
        my ($lang, $sele) = ($arg, '');
        if ($arg =~ /_/) {
            ($lang, $sele) = split /_/, $arg;
        }
        if ( Treex::Moose::is_lang_code($lang) ) {
            my $files_string = $args->{$arg};
            $files_string =~ s/^\s+|\s+$//g;
            my @files = split( /[ ,]+/,  $files_string);
            if ( !$self->_files_per_zone ) {
                $self->_set_files_per_zone( scalar @files );
            }
            elsif ( @files != $self->_files_per_zone ) {
                log_fatal("All zones must have the same number of files");
            }
            $self->_filenames->{$arg} = \@files;
        }
        elsif ( $arg =~ /selector|language|scenario/ ) { }
        else                                           { log_warn "$lang is not a lang_code"; }
    }
}

sub current_filenames {
    my ($self) = @_;
    my $n = $self->_file_number;
    return if $n == 0 || $n > $self->_files_per_zone;
    return map { $_ => $self->_filenames->{$_}[ $n - 1 ] } keys %{ $self->_filenames };
}

sub next_filenames {
    my ($self) = @_;
    $self->_set_file_number( $self->_file_number + 1 );
    return $self->current_filenames;
}

sub new_document {
    my ( $self, $load_from ) = @_;
    my %filenames = $self->current_filenames();
    log_fatal "next_filenames() must be called before new_document()" if !%filenames;

    my ( $stem, $file_number ) = ( '', '' );
    my ( $volume, $dirs, $file );
    if ( $self->file_stem ) {
        ( $stem, $file_number ) = ( $self->file_stem, undef );
    }
    else {    # Magical heuristics how to choose default name for a document loaded from several files
        foreach my $lang ( keys %filenames ) {
            my $filename = $filenames{$lang};
            ( $volume, $dirs, $file ) = File::Spec->splitpath($filename);
            my ( $name, $extension ) = $file =~ /([^.]+)(\..+)?/;
            $name =~ s/[_-]?$lang[_-]?//gi;
            if ( !$name && !$stem ) {
                $name        = 'noname';
                $file_number = undef;
            }
            if ( $stem !~ /$name/ ) {
                $stem .= '_' if $stem ne '';
                $stem .= $name;
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

after 'reset' => sub {
    my $self = shift;
    $self->_set_file_number(0);
};

1;
