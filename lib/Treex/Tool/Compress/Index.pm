package Treex::Tool::Compress::Index;

use Moose;

use Treex::Core::Common;

use IO::Zlib;
use File::Slurp;

has '_str2idx' => (
    is => 'ro',
    isa => 'HashRef[Int]',
    default => sub {{}},
);

has '_idx2str' => (
    is => 'ro',
    isa => 'HashRef[Str]',
    default => sub {{}},
);

has '_last_idx' => (
    is => 'rw',
    isa => 'Int',
    default => 0,
);

sub get_index {
    my ($self, $str) = @_;
    my $idx = $self->_str2idx->{$str};
    if (!defined $idx) {
        $idx = $self->_last_idx + 1;
        $self->_set_last_idx($idx);
        $self->_str2idx->{$str} = $idx;
    }
    return $idx;
}

sub build_inverted_index {
    my ($self) = @_;

    foreach my $str (keys %{$self->_str2idx}) {
        my $idx = $self->_str2idx->{$str};
        $self->_idx2str->{$idx} = $str;
    }
}

sub get_str_for_idx {
    my ($self, $idx) = @_;
    return $self->_idx2str->{$idx};
}

sub save {
    my ($self, $filename) = @_;
    log_info "Storing index file into $filename...";
    write_file( $filename, {binmode => ':raw'},
        Compress::Zlib::memGzip(Storable::freeze($self->_str2idx)) )
    or log_fatal $!;
}

1;
