package Treex::Core::Stream;

use Moose;
use MooseX::FollowPBP;

has current_document => (
    is      => 'rw',
    writer  => 'set_current_document',
    reader  => 'get_current_document',
    trigger => sub {
        my $self = shift;
        $self->set_document_number( ( $self->get_document_number || 0 ) + 1 );

        #                             print "Document number: ".$self->get_document_number."\n";

    },
);

has document_number => (
    is      => 'rw',
    default => 0,
);

__PACKAGE__->meta->make_immutable;

1;

__END__

=head1 NAME

Treex::Core::Stream

=head1 SYNOPSIS

  my $scenario = Treex::Core::Scenario
    ->new({blocks =>[qw(StreamReader::Plain_text StreamWriter::Save_as_numbered_treex)]});

  my $stream = Treex::Core::Stream->new;

  $scenario->apply_on_stream($stream);

=head1 DESCRIPTION

Very simple support for stream-wise processing of treex documents.
In fact, it provides just methods set_current_document and get_current_document.

=head1 AUTHOR

Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>

=head1 COPYRIGHT

Copyright 2010 Zdenek Zabokrtsky
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README

