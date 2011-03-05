package Treex::Core::DocumentReader;
use Moose::Role;

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

# Is the document that was most recently returned by $self->next_document()
# supossed to be processed by this job?
# Job indices and document numbers are 1-based, so e.g. for
# jobs = 5, jobindex = 3 we want to load documents with numbers 3,8,13,18,...
# jobs = 5, jobindex = 5 we want to load documents with numbers 5,10,15,20,...
# i.e. those documents where (doc_number-1) % jobs == (jobindex-1).
sub is_current_document_for_this_job {
    my ($self) = @_;
    return 1 if !$self->jobindex;    
    return ($self->doc_number - 1) % $self->jobs == ( $self->jobindex - 1 ); 
}

# Returns a next document which should be processed by this job.
# If jobindex is set, returns "modulo number of jobs".
sub next_document_for_this_job {
    my ($self) = @_;
    my $doc = $self->next_document();
    while ($doc && !$self->is_current_document_for_this_job) {
        $doc = $self->next_document();
    }
    
    # TODO this is not very elegant
    # and it is also wrong, because if next_document issues some warnings,
    # these are printed into a wrong file.
    # However, I don't know how to get the correct doc_number before executing next_document.  
    if ($doc && $self->jobindex){
        Treex::Core::Run::_redirect_output( $self->outdir, $self->doc_number, $self->jobindex );
    }
    
    return $doc;
}

requires 'next_document';

# total number of documents that will be produced
# If the number is unknown, undef is returned.
requires 'number_of_documents';

sub number_of_documents_per_this_job {
    my ($self) = @_;
    my $total = $self->number_of_documents() or return;
    return $total if !$self->jobs;
    my $rest = $total % $self->jobs;
    my $div  = ($total-$rest) / $self->jobs;
    return $div + ($rest >= $self->jobindex ? 1 : 0);
}

1;

__END__

=head1 NAME

Treex::Core::DocumentReader

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 COPYRIGHT

Copyright 2011 Martin Popel
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README

