package Treex::Block::Read::BaseReader;
use Moose;
use Treex::Moose;

has language => ( isa => 'LangCode', is => 'ro', required => 1 );
has selector => ( isa => 'Selector', is => 'ro', default => '');

has filenames => ( 
    isa => 'ArrayRef[Str]',
    is => 'rw',
    lazy_build => 1,
    documentation => 'array of filenames to be loaded;'
                     . ' automatically initialized from the attribute "from"',
);

has from => ( 
    isa => 'Str',
    is => 'ro',
    documentation => 'space or comma separated list of filenames to be loaded',
);

has file_number => ( 
    isa => 'Int',
    is => 'ro',
    writer => '_set_file_number',
    default=>0,
    init_arg=>undef,
    documentation => 'Number of input files loaded so far.',
);

sub _build_filenames {
    my $self = shift;
    confess "Parameter 'from' must be defined!" if !defined $self->from;
    $self->set_filenames([split /[ ,]+/, $self->from]);
}

sub next_filename {
    my ($self) = @_;
    return if $self->file_number >= @{$self->filenames};
    my $filename = $self->filenames->[$self->file_number];
    $self->_set_file_number($self->file_number + 1);
    return $filename;
}

1;
