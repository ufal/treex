package Treex::Core::Block;

our $VERSION = '0.1';

use Moose;
use MooseX::FollowPBP;

has parameter => (is => 'rw');

sub process_stream {
    my ( $self, $stream ) = @_;
    $self->process_document($stream->get_current_document);
    # unimplemented
}


sub process_document {
    my ( $self, $document ) = @_;

    foreach my $bundle ( $document->get_bundles() ) {
        $self->process_bundle($bundle);
    }
    return;
}

sub process_bundle {
#    Report::fatal "process_bundle() is not (and could not be) implemented"
#        . " in the abstract class TectoMT::Block !";
}

sub get_block_name {
    my ($self) = @_;
    return ref($self);
}

sub get_required_share_files {
    return ();
}

1;

