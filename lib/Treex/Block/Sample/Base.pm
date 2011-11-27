package Treex::Block::Sample::Base;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Parallel::MessageBoard;

extends 'Treex::Core::Block';

has _documents => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub {[]},
    documentation => 'array accumulating all loaded documents',
);

has message_board => (  # TODO: this could be moved to a role, as it might be useful not only form sampling blocks
    is => 'rw',
    isa => 'Treex::Tool::Parallel::MessageBoard',
    documentation => 'message board shared by blocks of the same type executed in the same treex run',
);

sub BUILD {
    my ( $self ) = @_;
    $self->set_message_board(Treex::Tool::Parallel::MessageBoard->new(
        workdir => $self->scenario->runner->workdir,
        sharers => $self->scenario->runner->jobs,
        current => $self->scenario->runner->jobindex,
    ));
}

sub process_document {
    my ( $self, $document ) = @_;
    push @{$self->_documents}, $document;
}

sub process_documents {
    my ( $self, $documents_rf ) = @_;

    my $number_of_documents = scalar @{$self->documents};
    log_info "Let's tell other blocks that this one has $number_of_documents documents at its disposal";
    $self->message_board->write_message( { number => (scalar @{$self->documents})} );

    $self->message_board->synchronize; # let's wait for all blocks to count their documents

    foreach my $message ( $self->message_board->synchronize ) {
        $number_of_documents += $message->{number};
    }
    log_info "All blocks have $number_of_documents documents in total";
}

sub DEMOLISH {
    my ( $self ) = @_;
    $self->process_documents( $self->_documents );
}

1;

=encoding utf-8

=head1 NAME

Treex::Block::Sample::Base

=head1 DESCRIPTION

Base class for sampling blocks, which need random access
to all processed documents. All documents are first accumulated
in process_document() calls. $block->process_documents is invoked
when the block instance is to be destructed.

=head1 METHODS

$block->process_documents($doc_array_ref)
  - if this method is redefined in block's descendant class,
  it can be applied on all documents assigned to this job

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

