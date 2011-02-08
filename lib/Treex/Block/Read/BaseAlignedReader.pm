package Treex::Block::Read::BaseAlignedReader;
use Moose;
use Treex::Moose;

has selector => ( isa => 'Selector', is => 'ro', default => '');

has _filenames => ( 
    isa => 'HashRef[LangCode]',
    is => 'ro',
    init_arg => undef,
    default => sub { {} },
    #traits    => [ 'Hash' ],
    #handles   => { add_lang_filenames => 'set', },    
    documentation => 'mapping language->filenames to be loaded;'
                     . ' automatically initialized from constructor arguments',
);

has _files_per_language => ( is => 'rw', default => 0);

has _file_number => ( 
    isa => 'Int',
    is => 'rw',
    default=>0,
    init_arg=>undef,
    documentation => 'Number of n-tuples of input files loaded so far.',
);

sub BUILD {
    my ($self, $args) = @_;
    foreach my $arg (keys %{$args}){
        if (Treex::Moose::is_lang_code($arg)){
            my @files = split(/[ ,]+/, $args->{$arg});
            if (!$self->_files_per_language){
                $self->_set_files_per_language(scalar @files);
            } elsif (@files != $self->_files_per_language) {
                log_fatal("All languages must have the same number of files");
            }
            $self->_filenames->{$arg} = \@files;
        }
        elsif ($arg =~ /selector|language|scenario/){}
        else { log_warn "$arg is not a lang_code";}
    } 
}



sub next_filenames {
    my ($self) = @_;
    return if $self->_file_number >= $self->_files_per_language;
    my %filenames = map {$_ => $self->_filenames->{$_}[$self->_file_number]} keys %{$self->_filenames};
    $self->_set_file_number($self->_file_number + 1);
    return %filenames;
}

1;
