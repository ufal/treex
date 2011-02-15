package Treex::Block::Read;
use Moose;
use Treex::Moose;
with 'Treex::Core::DocumentReader';
use English '-no_match_vars';

my %READER_FOR = (
    treex => 'Treex',
    txt   => 'Text',

    # TODO:
    # conll  => 'Conll',
    # plsgz  => 'Plsgz',
    # treex.gz
    # tmt
);

has from => (
    isa           => 'Str',
    is            => 'ro',
    required      => 1,
    documentation => 'space or comma separated list of filenames to be loaded',
);

has _reader => (
    is      => 'rw',
    handles => {
        'set_modulo' => 'set_modulo',
        'set_jobs'   => 'set_jobs',
        }
);

sub BUILD {
    my ( $self, $args ) = @_;
    my @files = split /[ ,]+/, $self->from;
    my ( $ext, @extensions ) = map {/[^.]+\.(.+)?/} @files;
    log_fatal 'Files (' . $self->from . ') must have extensions' if !$ext;
    log_fatal 'All files (' . $self->from . ') must have the same extension' if any { $_ ne $ext } @extensions;

    my $r = $READER_FOR{$ext};
    log_fatal "There is no DocumentReader implemented for extension '$ext'" if !$r;
    my $reader;
    eval "require Treex::Block::Read::$r; "
        . "\$reader = Treex::Block::Read::$r->new(\$args);";
    log_fatal "Error in loading a reader $EVAL_ERROR" if $EVAL_ERROR;
    $self->_set_reader($reader);
}

sub next_document {
    my ($self) = @_;
    return $self->_reader->next_document();
}

sub number_of_documents {
    my $self = shift;
    return $self->_reader->number_of_documents;
}

1;

__END__

Copyright 2011 Martin Popel
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
