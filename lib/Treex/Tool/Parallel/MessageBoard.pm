package Treex::Tool::Parallel::MessageBoard;

use Moose;
use Treex::Core::Common;

has directory => (
    is => 'rw',
    isa => 'Str',
    documentation => 'directory in which messages are stored',
);

has sharers => (
    is => 'rw',
    isa => 'Int',
    documentation => 'total number of talking and/or listening participants',
);

has current => (
    is => 'rw',
    isa => 'Int',
    documentation => 'the number representing the current participant',
);

sub BUILD {
    my ( $self ) = @_;
    if ( $self->current and $self->current > $self->sharers ) {
        log_fatal 'Number of the current participant cannnot be higher than the total number of participants';
    }
    if (not -d $self->directory) {
        log_fatal 'Directory '.$self->directory.' does not exists.';
    }
}

sub init {
    my ( $self ) = @_;
    mkdir $self->directory."/msg_board" or log_fatal $!;
    foreach my $i (1..$self->sharers) {
        mkdir $self->directory."/msg_board/from_".sprintf("%03d",$i) or log_fatal $!;
        mkdir $self->directory."/msg_board/for_".sprintf("%03d",$i) or log_fatal $!;
    }
}


sub write_message {
    my ( $self, $message ) = @_;

    return 1;
}

sub read_message {
    my ( $self ) = @_;
    my $message;
    return $message;
}

sub read_messages {
    my ( $self ) = @_;
    my @messages;
    while ( my $message = $self->read_message ) {
        push @messages, $message;
    }
    return @messages;
}

1;
