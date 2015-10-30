package Treex::Core::DocumentReader;

use Moose::Role;

# with Moose >= 2.00, this must be present also in roles
use MooseX::SemiAffordanceAccessor 0.09;

requires 'next_document';

requires 'number_of_documents';

# attrs for distributed processing
# TODO: check jobs >= jobindex > 0
has jobs => (
    is            => 'rw',
    isa           => 'Int',
    documentation => 'number of jobs for parallel processing',
);

has jobindex => (
    is            => 'rw',
    isa           => 'Int',
    documentation => 'ordinal number of the current job in parallel processing',
);

# TODO: this should not be needed in future
has outdir => (
    is  => 'rw',
    isa => 'Str',
);

has doc_number => (
    isa           => 'Int',
    is            => 'ro',
    writer        => '_set_doc_number',
    default       => 0,
    init_arg      => undef,
    documentation => 'Number of documents loaded so far, i.e.'
        . ' the ordinal number of the current (most recently loaded) document.',
);

has consumer => (
    isa => 'Treex::Block::Read::ConsumerReader',
    is  => 'rw'
);

sub next_document_for_this_job {
    my ($self) = @_;

    # In parallel execution, the file name is sent from the head to the workers via TCP
    # and only one doc per file is allowed, so we can override the file list to contain just
    # the file to be processed and set the $self->file_number counter to 0 – just before the file
    # to be processed (we will get another file name and reset it again next time).
    #
    # $self->doc_number is set to the number of processed files minus 1 since it will be increased
    # in next_document().
    #
    # This is an ugly hack (next_filename _set_file_number is defined only in BaseReader and BaseAlignedReader),
    # but this code must be specified here in next_document_for_this_job because the method next_filename
    # may be overriden or may not be used at all (e.g., BaseTextReader delegates its functionality
    # to Treex::Core::Files).

    if ( $self->consumer ) {
        my $res = $self->consumer->call("next_filename");
        if ($res) {
            $self->_set_file_number(0);
            $self->_set_doc_number( $res->{file_number} - 1 );
            $self->from->_set_filenames( [ $res->{result} ] );
        }

        # Martin Majliš had the following for BaseAlignedReader but I see no reason for it.
        # elsif ($self->_files_per_zone){
        #    $self->_set_file_number($self->_files_per_zone + 2);
        #}
        else {
            return;
        }
    }

    my $doc = $self->next_document();

    # TODO this is not very elegant
    # and it is also wrong, because if next_document issues some warnings,
    # these are printed into a wrong file.
    # However, I don't know how to get the correct doc_number before executing next_document.
    # Regarding  perlcritic ProtectPrivateSubs:
    # I consider _redirect_output as internal for Treex::Core modules.
    # print STDERR "DOC: " . $doc . " : " . $self->doc_number . ", JOB: " . $self->jobindex . "\n";

    if ( $doc && $self->jobindex ) {
        Treex::Core::Parallel::Node::_redirect_output( $self->outdir, $self->doc_number, $self->jobindex );    ## no critic (ProtectPrivateSubs)
    }

    return $doc;
}

sub number_of_documents_per_this_job {
    my ($self) = @_;
    my $total = $self->number_of_documents() or return;
    return $total if !$self->jobs;
    my $rest = $total % $self->jobs;
    my $div  = ( $total - $rest ) / $self->jobs;
    return $div + ( $rest >= $self->jobindex ? 1 : 0 );
}

sub restart {
    my ($self) = @_;
    $self->_set_doc_number(0);
    return;
}

# Readers usually do not need any share files,
# but all blocks should implement this method
# and readers do not extend Treex::Core::Block.
sub get_required_share_files {
    my ($self) = @_;
    return ();
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Core::DocumentReader - interface for all document readers

=head1 DESCRIPTION

Document readers are a Treex concept how to load documents to be processed by Treex.
The documents can be stored in files (in various formats) or read from C<STDIN>
or retrieved from a socket etc.

=head1 METHODS

=head2 To be implemented

These methods must be implemented in classes that consume this role.

=over

=item next_document

Return next document (L<Treex::Core::Document>).

=item number_of_documents

Total number of documents that will be produced by this reader.
If the number is unknown in advance, C<undef> should be returned.

=back

=head2 Already implemented

=over

=item is_current_document_for_this_job

Is the document that was most recently returned by C<$self->next_document()>
supposed to be processed by this job?
Job indices and document numbers are 1-based, so e.g. for
C<jobs = 5, jobindex = 3> we want to load documents with numbers 3,8,13,18,...
C<jobs = 5, jobindex = 5> we want to load documents with numbers 5,10,15,20,...
i.e. those documents where C<(doc_number-1) % jobs == (jobindex-1)>.

=item next_document_for_this_job

Returns a next document which should be processed by this job.
If C<jobindex> is set, returns "modulo number of jobs".
See C<is_current_document_for_this_job>.

=item number_of_documents_per_this_job

Total number of documents that will be produced by this reader for this job.
It's computed based on C<number_of_documents>, C<jobindex> and C<jobs>.

=item restart

Start reading again from the first document.
This implementation just sets the attribute C<doc_number> to zero.
You can add additional behavior using the Moose C<after 'restart'> construct.

=back

=head1 SEE ALSO

L<Treex::Block::Read::Sentences>
L<Treex::Block::Read::Text>
L<Treex::Block::Read::Treex>


=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
