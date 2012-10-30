package Treex::Tool::Compress::Index;

use Moose;

use Treex::Core::Common;

with 'Treex::Tool::Storage::Storable';

has 'str2idx' => (
    is => 'rw',
    isa => 'HashRef[Int]',
    default => sub {{}},
);

has '_idx2str' => (
    is => 'ro',
    isa => 'HashRef[Str]',
    default => sub {{}},
);

has 'last_idx' => (
    is => 'ro',
    isa => 'Int',
    writer => '_set_last_idx',
    default => 0,
);

sub get_index {
    my ($self, $str) = @_;
    my $idx = $self->str2idx->{$str};
    if (!defined $idx) {
        $idx = $self->last_idx + 1;
        $self->_set_last_idx($idx);
        $self->str2idx->{$str} = $idx;
    }
    return $idx;
}

sub all_labels {
    my ($self) = @_;
    return keys %{$self->str2idx};
}

sub build_inverted_index {
    my ($self) = @_;

    foreach my $str (keys %{$self->str2idx}) {
        my $idx = $self->str2idx->{$str};
        $self->_idx2str->{$idx} = $str;
    }
}

sub get_str_for_idx {
    my ($self, $idx) = @_;
    return $self->_idx2str->{$idx};
}

############# implementing Treex::Tool::Storage::Storable role #################

before 'save' => sub {
    my ($self, $filename) = @_;
    log_info "Storing index file into $filename...";
};

before 'load' => sub {
    my ($self, $filename) = @_;
    log_info "Loading index file from $filename...";
};

sub freeze {
    my ($self) = @_;
    return [$self->str2idx, $self->last_idx];
}

sub thaw {
    my ($self, $buffer) = @_;
    $self->set_str2idx( $buffer->[0] );
    $self->_set_last_idx( $buffer->[1] );
}

1;
