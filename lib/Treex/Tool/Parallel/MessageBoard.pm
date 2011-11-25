package Treex::Tool::Parallel::MessageBoard;

use Moose;
use Treex::Core::Common;
use File::Temp qw(tempdir);

has path => (
    is => 'rw',
    isa => 'Str',
    default => '.',
    documentation => 'directory in which working directory structure will be created',
);

has workdir => (
    is => 'rw',
    isa => 'Str',
    documentation => 'working directory created for storing messages',
);

has sharers => (
    is => 'rw',
    isa => 'Int',
    documentation => 'total number of talking and/or listening participants',
);

has current => (
    is => 'rw',
    isa => 'Int',
    documentation => 'the number representing the current participant (1 <= current <= sharers)',
);

sub BUILD {
    my ( $self ) = @_;

    if ( $self->current and $self->current > $self->sharers ) {
        log_fatal 'Number of the current participant cannnot be higher than the total number of participants';
    }

    if ( not $self->workdir ) {
        my $counter;
        my $directory_prefix;
        my @existing_dirs;

        # search for the first unoccupied directory prefix
        do {
            $counter++;
            $directory_prefix = sprintf $self->path."/%03d-message-board-", $counter;
            @existing_dirs = glob "$directory_prefix*";
        }
            while (@existing_dirs);

        my $directory = tempdir "${directory_prefix}XXXXX" or log_fatal($!);
        $self->set_workdir($directory);
        log_info "Working directory $directory created";
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
