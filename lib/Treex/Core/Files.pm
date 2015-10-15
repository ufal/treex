package Treex::Core::Files;

use Moose;
use MooseX::SemiAffordanceAccessor 0.09;
use Treex::Core::Log;
use autodie;
use File::Slurp 9999.19;
use Digest::MD5 qw(md5_hex);
use PerlIO::via::gzip;
use File::Basename;

has filenames => (
    is     => 'ro',
    isa    => 'ArrayRef[Str]',
    writer => '_set_filenames',
);

has file_number => (
    isa           => 'Int',
    is            => 'ro',
    writer        => '_set_file_number',
    default       => 0,
    init_arg      => undef,
    documentation => 'Number of the current file',
);

has current_filehandle => (
    is => 'ro',
    writer => '_set_current_filehandle',
);

has encoding => (
    isa => 'Str',
    is => 'rw',
    default  => 'utf8',
);

has join_files_for_next_line => (
    isa => 'Bool',
    is => 'ro',
    default  => 1,
    documentation => 'Should method next_line automatically go to the next file when finished reading the current file?',
);

sub BUILD {
    my ( $self, $args ) = @_;
    if ($args->{filenames}){
        ## Nothing to do, $args->{filenames} are ArrayRef[Str] checked by Moose
    } elsif(defined $args->{string}){
        $self->_set_filenames( $self->string_to_filenames( $args->{string} ) );
    } else {
        log_fatal 'One of the parameters (filenames, string)  is required';
    }
    return;
}

sub string_to_filenames {
    my ( $self, $string ) = @_;
    
    # "!" means glob pattern which can contain {dir1,dir2}
    # so it cannot be combined with separating tokens with comma.
    if ($string =~ /^!(.+)/) {
        my @filenames = glob $1;
        log_warn "No filenames matched '$1' pattern" if !@filenames;
        return \@filenames;
    }
    
    return [ map { $self->_token_to_filenames($_) } grep {/./} split /[ ,]+/, $string ];
}

sub _token_to_filenames {
    my ( $self, $token ) = @_;
    if ($token =~ /^!(.+)/) {
        my @filenames = glob $1;
        log_warn "No filenames matched '$1' pattern" if !@filenames;
        return @filenames;
    }
    return $token if $token !~ s/^@(.*)/$1/;
    my $filelist = $token eq '-' ? \*STDIN : $token;
    my @filenames = grep { $_ ne '' } read_file( $filelist, chomp => 1 );

    # Filnames in a filelist can be relative to the filelist directory.
    my $dir = dirname($token);
    return @filenames if $dir eq '.';
    return map {!m{^/} ? "$dir/$_" : $_} @filenames;
}

sub number_of_files {
    my ($self) = @_;
    return scalar @{ $self->filenames };
}

sub current_filename {
    my ($self) = @_;
    return if $self->file_number == 0 || $self->file_number > @{ $self->filenames };
    return $self->filenames->[ $self->file_number - 1 ];
}

sub next_filename {
    my ($self) = @_;
    $self->_set_file_number( $self->file_number + 1 );
    return $self->current_filename();
}

sub has_next_file {
    my ($self) = @_;
    return $self->file_number < $self->number_of_files;
}

sub get_hash {
    my $self = shift;

    my $md5 = Digest::MD5->new();
    for my $filename (@{$self->filenames}) {
        if ( -f $filename ) {
            $md5->add($filename);
            $md5->add((stat($filename))[9]);
        }
    }
    return $md5->hexdigest;
}

sub next_filehandle {
    my ($self) = @_;
    my $filename = $self->next_filename();
    my $FH = $self->current_filehandle;
    
    if (!defined $filename){
        $FH = undef;
    }
    elsif ( $filename eq '-' ) {
        binmode STDIN, $self->encoding;
        $FH = \*STDIN;
    }
    else {
        my $mode = $filename =~ /[.]gz$/ ? '<:via(gzip):' : '<:';
        $mode .= $self->encoding;
        open $FH, $mode, $filename or log_fatal "Can't open $filename: $!";
    }
    $self->_set_current_filehandle($FH);
    return $FH;
}

sub next_file_text {    
    my ($self) = @_;
    my $FH = $self->next_filehandle() or return;

    # Slurp that is compatible with Perl::IO::via::gzip.
    local $/ = undef;
    return <$FH>;
}

sub next_line {
    my ($self) = @_;
    my $FH = $self->current_filehandle;
    return if !$FH && !$self->join_files_for_next_line;
    if ( !$FH ) {
        $FH = $self->next_filehandle() or return;
    }
    return <$FH>;
}

#<<<
use Moose::Util::TypeConstraints;
coerce 'Treex::Core::Files'
    => from 'Str'
        => via { Treex::Core::Files->new( string => $_ ) }
    => from 'ArrayRef[Str]'
        => via { Treex::Core::Files->new( filenames => $_ ) };
#>>>
# TODO: POD, next_filehandle, gz support

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Treex::Core::Files - helper class for iterating over filenames

=head1 SYNOPSIS

  package My::Class;
  use Moose;

  has from => (
      is => 'ro',
      isa => 'Treex::Core::Files',
      coerce => 1,
      handles => [qw(next_filename current_filename)],
  );

  # and then
  my $c = My::Class(from=>'f1.txt f2.txt.gz @my.filelist');

  while (defined (my $filename = $c->next_filename)){ ... }
  #or
  while (my $filehandle = $c->next_filehandle){ ... }

  # You can use also wildcard expansion
  my $c = My::Class(from=>'!dir??/file*.txt');


=head1 DESCRIPTION

The I<@filelist> and I<!wildcard> conventions are used in several tools, e.g. 7z or javac.
For a large number of files, list the file names in a file - one per line.
Then use the list file name preceded by an @ character.

Methods <next_*> serve as iterators and return undef if the called after the last file is reached.

=head1 METHODS

=head2 number_of_files

Returns the total number of files contained by this instance.

=head2 file_number

Returns ordinal number (1..number_of_files) of the current file.

=head2 current_filename

Returns the current filename or undef if the iterator is before the first file
(i.e. C<next_filename> has not been called so far) or after the last file.

=head2 next_filename

Returns the next filename (and increments the file_number).

=head2 current_filehandle

Opens the current file for reading and returns the filehandle.
Filename "-" is interpreted as STDIN.
Filenames with extension ".gz" are opened via L<PerlIO::via::gzip> (ie. unzipped on the fly).

=head2 next_filehandle

Returns the next filehandle (and increments the file_number).

=head2 next_file_text

Returns the content of the next file (slurp) and increments the file_number.

=head2 next_line

Returns the next line of the current file.
If the end of file is reached and attribute C<join_files_for_next_line> is set to true (which is by default),
the first line of next file is returned (and file_number incremented).

=head2 get_hash

Returns MD5 hash computed from the filenames and last modify times.

=head2 $filenames_ref = string_to_filenames($string)

Helper method that expands comma-or-space-separated list of filenames
and returns an array reference containing the filenames.
If the string starts with "!", it is interpreted as wildcards (see Perl L<glob>).
If a filename starts with "@" it is interpreted as a file list with one filename per line.

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
