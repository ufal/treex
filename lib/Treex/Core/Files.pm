package Treex::Core::Files;
use Moose;
use MooseX::SemiAffordanceAccessor 0.09;
use Treex::Core::Log;
use autodie;
use File::Slurp 9999.19;
use Digest::MD5 qw(md5_hex);

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
    documentation => 'Number of input files loaded so far.',
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
    return [ map { $self->_token_to_filenames($_) } grep {/./} split /[ ,]+/, $string ];
}

sub _token_to_filenames {
    my ( $self, $token ) = @_;
    if ($token =~ /^!(.+)/) {
        my @filenames = glob $1;
        return @filenames;
    }
    return $token if $token !~ s/^@(.*)/$1/;
    if ( $token eq '-' ) {
        $token = \*STDIN;
    }
    my @filenames = read_file( $token, chomp => 1 );
    return @filenames;
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

TODO more doc

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
